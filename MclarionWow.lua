local ADDON_NAME = ...

local function isSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function combatStatus()
    if type(issecretvalue) ~= "function" or type(issecrettable) ~= "function" then
        return nil, "Protection checks are unavailable."
    end
    local check = InCombatLockdown
    if isSecret(check) then return nil, "Combat API is protected by the client." end
    if type(check) ~= "function" then return nil, "Combat API is unavailable." end
    local value = check()
    if isSecret(value) then return nil, "Combat status is protected by the client." end
    if type(value) ~= "boolean" then return nil, "Combat status is unavailable." end
    return value
end

local function rejectSecret(label, value)
    if isSecret(value) then
        return nil, label .. " is protected by the client."
    end
    return value
end

local function escapeText(value)
    value = value:gsub("%%", "%%25")
    value = value:gsub("|", "%%7C")
    return value
end

local function positiveInteger(value)
    return type(value) == "number" and value > 0 and value < math.huge and
        value == math.floor(value)
end

local function nonnegativeInteger(value)
    return type(value) == "number" and value >= 0 and value < math.huge and
        value == math.floor(value)
end

local function exportApisAvailable(...)
    for index = 1, select("#", ...) do
        local api = select(index, ...)
        if isSecret(api) then return nil, "Export API is protected by the client." end
        if type(api) ~= "function" then return nil, "Export API is unavailable." end
    end
    return true
end

function MclarionWow_BuildExport()
    local combat, combatError = combatStatus()
    if combat == nil then return nil, combatError end
    if combat then
        return nil, "MclarionWow will not export while you are in combat."
    end
    local apisAvailable, apiError = exportApisAvailable(GetServerTime, UnitGUID, UnitName,
        GetRealmName, UnitClass, UnitLevel, GetZoneText, GetBuildInfo, GetInventoryItemID)
    if not apisAvailable then return nil, apiError end

    local serverTime = GetServerTime()
    local playerGuid = UnitGUID("player")
    local playerName = UnitName("player")
    local realmName = GetRealmName()
    local _, classFile = UnitClass("player")
    local level = UnitLevel("player")
    local mapId
    local map = C_Map
    if isSecret(map) or (type(map) == "table" and issecrettable(map)) then
        return nil, "Map API is protected by the client."
    end
    if type(map) == "table" then
        local mapLookup = map.GetBestMapForUnit
        if isSecret(mapLookup) then return nil, "Map API is protected by the client." end
        if type(mapLookup) == "function" then mapId = mapLookup("player") end
    end
    local zoneText = GetZoneText()
    local _, buildString = GetBuildInfo()
    local _, buildSecretError = rejectSecret("build", buildString)
    if buildSecretError then
        return nil, buildSecretError
    end
    local build = tonumber(buildString)

    local values = {
        { "server time", serverTime },
        { "player GUID", playerGuid },
        { "player name", playerName },
        { "realm name", realmName },
        { "class", classFile },
        { "level", level },
        { "map ID", mapId },
        { "zone", zoneText },
        { "build", build },
    }
    for _, entry in ipairs(values) do
        local _, secretError = rejectSecret(entry[1], entry[2])
        if secretError then
            return nil, secretError
        end
    end

    if not positiveInteger(serverTime) or serverTime > 253402300799 then
        return nil, "Server time is unavailable."
    end
    if type(playerGuid) ~= "string" or #playerGuid < 11 or #playerGuid > 77 or
        not playerGuid:match("^Player%-[A-Za-z0-9%-]+$") then
        return nil, "A valid player GUID is unavailable."
    end
    if type(playerName) ~= "string" or playerName == "" or #playerName > 80 then
        return nil, "Player name is unavailable."
    end
    if playerName:find("[%c]") then
        return nil, "Player name contains unsupported control characters."
    end
    if type(realmName) ~= "string" or realmName == "" or #realmName > 80 then
        return nil, "Realm name is unavailable."
    end
    if realmName:find("[%c]") then
        return nil, "Realm name contains unsupported control characters."
    end
    if type(classFile) ~= "string" or #classFile < 3 or #classFile > 20 or
        not classFile:match("^[A-Z]+$") then
        return nil, "Player class is unavailable."
    end
    if not positiveInteger(level) or level > 2147483647 then
        return nil, "Player level must be positive."
    end
    if mapId == nil then
        mapId = 0
    elseif not nonnegativeInteger(mapId) or mapId > 2147483647 then
        return nil, "Map ID is invalid."
    end
    if type(zoneText) ~= "string" or zoneText == "" or #zoneText > 120 then
        return nil, "Zone name is unavailable."
    end
    if zoneText:find("[%c]") then
        return nil, "Zone name contains unsupported control characters."
    end
    if not positiveInteger(build) or build > 2147483647 then
        return nil, "Client build must be positive."
    end

    local gearIds = {}
    for slot = 1, 19 do
        local itemId = GetInventoryItemID("player", slot)
        if isSecret(itemId) then
            return nil, "Inventory slot " .. slot .. " is protected by the client."
        end
        if itemId == nil then
            itemId = 0
        elseif not nonnegativeInteger(itemId) or itemId > 2147483647 then
            return nil, "Inventory slot " .. slot .. " has an invalid item ID."
        end
        gearIds[slot] = tostring(itemId)
    end

    local export = table.concat({
        "MHWOW1",
        "forever",
        tostring(serverTime),
        playerGuid,
        escapeText(playerName),
        escapeText(realmName),
        classFile,
        tostring(level),
        tostring(mapId),
        escapeText(zoneText),
        table.concat(gearIds, ","),
        tostring(build),
    }, "|")
    if #export > 4096 then return nil, "Character export is too large." end
    return export, nil, playerGuid
end

-- Additive character identity format; MHWOW1 remains available for older importers.
function MclarionWow_BuildIdentityExport()
    local export, err, guid = MclarionWow_BuildExport()
    if not export then return nil, err end
    local available, apiError = exportApisAvailable(UnitFactionGroup, UnitRace, UnitSex)
    if not available then return nil, apiError end
    local faction = UnitFactionGroup("player")
    local _, race = UnitRace("player")
    local sex = UnitSex("player")
    if isSecret(faction) or isSecret(race) or isSecret(sex) then
        return nil, "Player identity is protected by the client."
    end
    if faction ~= "Alliance" and faction ~= "Horde" and faction ~= "Neutral" then
        return nil, "Player faction is unavailable."
    end
    if type(race) ~= "string" or #race < 2 or #race > 32 or
        not race:match("^[A-Za-z]+$") then
        return nil, "Player race is unavailable."
    end
    if sex ~= 1 and sex ~= 2 and sex ~= 3 then
        return nil, "Player gender is unavailable."
    end
    local gender = sex == 2 and "Male" or (sex == 3 and "Female" or "Unknown")
    local result = export:gsub("^MHWOW1|", "MHWOW2|", 1) .. "|" ..
        faction .. "|" .. race .. "|" .. gender
    if #result > 4096 then return nil, "Character export is too large." end
    return result, nil, guid
end

-- Shared, fail-closed scanner for diagnostics and automatic bag capture.
local function scanBags(collectTotals)
    local combat, combatError = combatStatus()
    if combat == nil then return nil, combatError end
    if combat then
        return nil, "Bag probe is unavailable during combat."
    end
    if isSecret(C_Container) or type(C_Container) ~= "table" or issecrettable(C_Container) then
        return nil, "Bag API is unavailable."
    end
    local getSlots, getInfo = C_Container.GetContainerNumSlots, C_Container.GetContainerItemInfo
    if isSecret(getSlots) or isSecret(getInfo) or
        type(getSlots) ~= "function" or type(getInfo) ~= "function" then
        return nil, "Bag API is unavailable."
    end

    local slotsTotal, occupied, distinct = 0, 0, 0
    local seen = {}
    local totals = collectTotals and {} or nil
    for bag = 0, 4 do
        local slots = getSlots(bag)
        if isSecret(slots) then
            return nil, "Bag slot count is protected by the client."
        end
        if not nonnegativeInteger(slots) or slots > 120 then
            return nil, "Bag slot count is unavailable."
        end
        -- A player always has a backpack. Zero here is an uninitialized view,
        -- not evidence that the character emptied all of their bags.
        if bag == 0 and slots == 0 then
            return nil, "Backpack slots are unavailable."
        end
        slotsTotal = slotsTotal + slots
        for slot = 1, slots do
            local item = getInfo(bag, slot)
            if isSecret(item) then
                return nil, "Bag item is protected by the client."
            end
            if type(item) == "table" then
                if issecrettable(item) then
                    return nil, "Bag item is protected by the client."
                end
                local itemId, count = item.itemID, item.stackCount
                if isSecret(itemId) or isSecret(count) then
                    return nil, "Bag item value is protected by the client."
                end
                if not positiveInteger(itemId) or itemId > 2147483647 or
                    not positiveInteger(count) or count > 2147483647 then
                    return nil, "Bag item value is invalid."
                end
                if totals then
                    local total = (totals[itemId] or 0) + count
                    if total > 2147483647 then
                        return nil, "Bag item total is too large."
                    end
                    totals[itemId] = total
                end
                occupied = occupied + 1
                if not seen[itemId] then
                    seen[itemId] = true
                    distinct = distinct + 1
                end
            elseif item ~= nil then
                return nil, "Bag item has an unsupported format."
            end
        end
    end
    return string.format("Bag probe: %d slots, %d occupied, %d distinct items. No bag data saved.",
        slotsTotal, occupied, distinct), totals
end

function MclarionWow_ProbeBags()
    local report, err = scanBags(false)
    return report, err
end

-- Capability check only: neither a row count nor an unavailable API proves
-- which quests or factions the player has. Do not persist probe results.
local function progressionRowCount(legacy, namespace, method)
    if isSecret(legacy) then return "protected" end
    local read = legacy
    if type(read) ~= "function" then
        if isSecret(namespace) or
            (type(namespace) == "table" and issecrettable(namespace)) then
            return "protected"
        end
        if type(namespace) ~= "table" then return "unavailable" end
        read = namespace[method]
    end
    if isSecret(read) then return "protected" end
    if type(read) ~= "function" then return "unavailable" end
    local ok, count = pcall(read)
    if not ok then return "unavailable" end
    if isSecret(count) then return "protected" end
    if not nonnegativeInteger(count) or count > 2048 then return "unavailable" end
    return tostring(count)
end

function MclarionWow_ProbeProgression()
    local combat, err = combatStatus()
    if combat == nil then return nil, err end
    if combat then return nil, "Progression probe is unavailable during combat." end
    local quests = progressionRowCount(GetNumQuestLogEntries, C_QuestLog,
        "GetNumQuestLogEntries")
    local factions = progressionRowCount(GetNumFactions, C_Reputation, "GetNumFactions")
    return string.format("Quest-log rows: %s (headers included); faction rows: %s " ..
        "(collapsed sections may be hidden). No progression data saved.", quests, factions)
end

-- Diagnostic only. Read candidate leaf shapes without keeping IDs or values.
-- An unsupported row refuses its category rather than silently omitting it.
local function progressionRecordMethod(api, namespace, candidateName)
    if isSecret(api) then return nil, "protected" end
    if type(api) ~= "function" then
        if isSecret(namespace) or
            (type(namespace) == "table" and issecrettable(namespace)) then
            return nil, "legacy getter missing (namespaced candidate protected)"
        end
        if type(namespace) == "table" then
            local ok, candidate = pcall(function() return namespace[candidateName] end)
            if not ok then
                return nil, "legacy getter missing (namespaced candidate inaccessible)"
            end
            if isSecret(candidate) then
                return nil, "legacy getter missing (namespaced candidate protected)"
            end
            if type(candidate) == "function" then
                return nil, "legacy getter missing (namespaced candidate present)"
            end
        end
        return nil, "legacy getter missing (namespaced candidate absent)"
    end
    return api
end

local function boundedStandingValue(value)
    return type(value) == "number" and value >= -2147483647 and
        value <= 2147483647 and value == math.floor(value)
end

local function questRecordSummary()
    local rows = progressionRowCount(GetNumQuestLogEntries, C_QuestLog,
        "GetNumQuestLogEntries")
    if rows == "protected" or rows == "unavailable" then return rows end
    local count = tonumber(rows)
    if count > 128 then return "over limit" end
    local read, reason = progressionRecordMethod(GetQuestLogTitle, C_QuestLog, "GetInfo")
    if not read then return reason end
    local leaves = 0
    for index = 1, count do
        local ok, _, _, _, header, _, _, _, questId = pcall(read, index)
        if not ok then return "getter call failed" end
        if isSecret(header) or isSecret(questId) then return "protected" end
        if type(header) ~= "boolean" then return "header flag invalid" end
        if not header then
            if not positiveInteger(questId) or questId > 2147483647 then
                return "quest ID invalid"
            end
            leaves = leaves + 1
        end
    end
    return leaves .. "/" .. count
end

local function factionRecordSummary()
    local rows = progressionRowCount(GetNumFactions, C_Reputation, "GetNumFactions")
    if rows == "protected" or rows == "unavailable" then return rows end
    local count = tonumber(rows)
    if count > 256 then return "over limit" end
    local read, reason = progressionRecordMethod(GetFactionInfo, C_Reputation,
        "GetFactionDataByIndex")
    if not read then return reason end
    local leaves = 0
    for index = 1, count do
        local ok, _, _, standing, barMin, barMax, barValue, _, _, header,
            _, _, _, _, factionId = pcall(read, index)
        if not ok then return "getter call failed" end
        if isSecret(header) or isSecret(factionId) or isSecret(standing) or
            isSecret(barMin) or isSecret(barMax) or isSecret(barValue) then
            return "protected"
        end
        if type(header) ~= "boolean" then return "header flag invalid" end
        if not header then
            if not positiveInteger(factionId) or factionId > 2147483647 then
                return "faction ID invalid"
            end
            if not positiveInteger(standing) or standing > 16 then
                return "standing invalid"
            end
            if not boundedStandingValue(barMin) or
                not boundedStandingValue(barMax) or
                not boundedStandingValue(barValue) or barMin >= barMax or
                barValue < barMin or barValue > barMax then
                return "bar values invalid"
            end
            leaves = leaves + 1
        end
    end
    return leaves .. "/" .. count
end

function MclarionWow_ProbeProgressionRecords()
    local combat, err = combatStatus()
    if combat == nil then return nil, err end
    if combat then return nil, "Progression record probe is unavailable during combat." end
    local quests = questRecordSummary()
    local factions = factionRecordSummary()
    return string.format("Quest records: %s; faction records: %s (visible rows only). " ..
        "No progression data saved.", quests, factions)
end

-- Diagnostic only: this client-build candidate returns row tables, unlike
-- the legacy multi-return getters. Never retain or print their fields.
local function namespacedProgressionMethod(namespace, name)
    if isSecret(namespace) then return nil, "protected" end
    if type(namespace) ~= "table" then return nil, "namespace missing" end
    if issecrettable(namespace) then return nil, "protected" end
    local ok, method = pcall(function() return namespace[name] end)
    if not ok then return nil, "getter inaccessible" end
    if isSecret(method) then return nil, "protected" end
    if type(method) ~= "function" then return nil, "getter missing" end
    return method
end

local function namespacedProgressionCount(namespace, name, limit)
    local read, reason = namespacedProgressionMethod(namespace, name)
    if not read then return nil, reason end
    local ok, count = pcall(read)
    if not ok then return nil, "count call failed" end
    if isSecret(count) then return nil, "protected" end
    if not nonnegativeInteger(count) then return nil, "count invalid" end
    if count > limit then return nil, "over limit" end
    return count
end

local function namespacedQuestSummary()
    local count, reason = namespacedProgressionCount(C_QuestLog,
        "GetNumQuestLogEntries", 128)
    if not count then return reason end
    local read
    read, reason = namespacedProgressionMethod(C_QuestLog, "GetInfo")
    if not read then return reason end
    local leaves = 0
    for index = 1, count do
        local ok, info = pcall(read, index)
        if not ok then return "row call failed" end
        if isSecret(info) then return "protected" end
        if type(info) ~= "table" then return "row missing" end
        if issecrettable(info) then return "protected" end
        local fieldsOk, header, logIndex = pcall(function()
            return info.isHeader, info.questLogIndex
        end)
        if not fieldsOk then return "field access failed" end
        if isSecret(header) or isSecret(logIndex) then
            return "protected"
        end
        if type(header) ~= "boolean" or not positiveInteger(logIndex) or
            logIndex ~= index then return "row shape invalid" end
        if not header then
            local idOk, questId = pcall(function() return info.questID end)
            if not idOk then return "field access failed" end
            if isSecret(questId) then return "protected" end
            if not positiveInteger(questId) or questId > 2147483647 then
                return "quest ID invalid"
            end
            leaves = leaves + 1
        end
    end
    return leaves .. "/" .. count
end

local function namespacedFactionSummary()
    local count, reason = namespacedProgressionCount(C_Reputation, "GetNumFactions", 256)
    if not count then return reason end
    local read
    read, reason = namespacedProgressionMethod(C_Reputation, "GetFactionDataByIndex")
    if not read then return reason end
    local leaves, headerRep, collapsed = 0, 0, 0
    for index = 1, count do
        local ok, info = pcall(read, index)
        if not ok then return "row call failed" end
        if isSecret(info) then return "protected" end
        if type(info) ~= "table" then return "row missing" end
        if issecrettable(info) then return "protected" end
        local fieldsOk, header, withRep, isCollapsed = pcall(function()
            return info.isHeader, info.isHeaderWithRep, info.isCollapsed
            end)
        if not fieldsOk then return "field access failed" end
        if isSecret(header) or isSecret(withRep) or isSecret(isCollapsed) then
            return "protected"
        end
        if type(header) ~= "boolean" or type(withRep) ~= "boolean" or
            type(isCollapsed) ~= "boolean" then return "row shape invalid" end
        if header then
            if withRep then headerRep = headerRep + 1 end
            if isCollapsed then collapsed = collapsed + 1 end
        else
            local leafOk, factionId, reaction, barMin, barMax, barValue = pcall(function()
                return info.factionID, info.reaction, info.currentReactionThreshold,
                    info.nextReactionThreshold, info.currentStanding
            end)
            if not leafOk then return "field access failed" end
            if isSecret(factionId) or isSecret(reaction) or isSecret(barMin) or
                isSecret(barMax) or isSecret(barValue) then return "protected" end
            if not positiveInteger(factionId) or factionId > 2147483647 then
                return "faction ID invalid"
            end
            if not positiveInteger(reaction) or reaction > 16 then
                return "reaction invalid"
            end
            if not boundedStandingValue(barMin) or
                not boundedStandingValue(barMax) or
                not boundedStandingValue(barValue) or barMin >= barMax or
                barValue < barMin or barValue > barMax then
                return "standing interval unsupported"
            end
            leaves = leaves + 1
        end
    end
    return string.format("%d/%d (header-rep %d, collapsed %d)", leaves,
        count, headerRep, collapsed)
end

function MclarionWow_ProbeProgressionNamespaced()
    local combat, err = combatStatus()
    if combat == nil then return nil, err end
    if combat then return nil, "Namespaced progression probe is unavailable during combat." end
    return string.format("Quest-log leaves: %s; faction visible: %s. No progression data saved.",
        namespacedQuestSummary(), namespacedFactionSummary())
end

-- Candidate diagnostic only. Compare complete bounded UI-index scans twice;
-- even agreement is evidence for this view, not an atomic game snapshot.
local function safetyQuestRow(read, index)
    local ok, info = pcall(read, index)
    if not ok then return nil, nil, "row call failed" end
    if isSecret(info) then return nil, nil, "protected" end
    if type(info) ~= "table" then return nil, nil, "row missing" end
    if issecrettable(info) then return nil, nil, "protected" end
    local fieldsOk, header, logIndex = pcall(function()
        return info.isHeader, info.questLogIndex
    end)
    if not fieldsOk then return nil, nil, "field access failed" end
    if isSecret(header) or isSecret(logIndex) then return nil, nil, "protected" end
    if type(header) ~= "boolean" or not positiveInteger(logIndex) or
        logIndex ~= index then return nil, nil, "row shape invalid" end
    if header then
        local titleOk, title = pcall(function() return info.title end)
        if not titleOk then return nil, nil, "field access failed" end
        if isSecret(title) then return nil, nil, "protected" end
        if type(title) ~= "string" or #title == 0 or #title > 256 then
            return nil, nil, "header identity unavailable"
        end
        return "header:" .. title, nil
    end
    local idOk, questId = pcall(function() return info.questID end)
    if not idOk then return nil, nil, "field access failed" end
    if isSecret(questId) then return nil, nil, "protected" end
    if not positiveInteger(questId) or questId > 2147483647 then
        return nil, nil, "quest ID invalid"
    end
    return tostring(questId), "leaf"
end

local function safetyFactionRow(read, index)
    local ok, info = pcall(read, index)
    if not ok then return nil, nil, "row call failed" end
    if isSecret(info) then return nil, nil, "protected" end
    if type(info) ~= "table" then return nil, nil, "row missing" end
    if issecrettable(info) then return nil, nil, "protected" end
    local fieldsOk, header, withRep, collapsed = pcall(function()
        return info.isHeader, info.isHeaderWithRep, info.isCollapsed
    end)
    if not fieldsOk then return nil, nil, "field access failed" end
    if isSecret(header) or isSecret(withRep) or isSecret(collapsed) then
        return nil, nil, "protected"
    end
    if type(header) ~= "boolean" or type(withRep) ~= "boolean" or
        type(collapsed) ~= "boolean" then return nil, nil, "row shape invalid" end
    if header then
        local nameOk, name = pcall(function() return info.name end)
        if not nameOk then return nil, nil, "field access failed" end
        if isSecret(name) then return nil, nil, "protected" end
        if type(name) ~= "string" or #name == 0 or #name > 256 then
            return nil, nil, "header identity unavailable"
        end
        return "header:" .. tostring(withRep) .. ":" .. tostring(collapsed) ..
            ":" .. name, nil
    end
    local leafOk, factionId, reaction, barMin, barMax, barValue, accountWide =
        pcall(function()
            return info.factionID, info.reaction, info.currentReactionThreshold,
                info.nextReactionThreshold, info.currentStanding, info.isAccountWide
        end)
    if not leafOk then return nil, nil, "field access failed" end
    if isSecret(factionId) or isSecret(reaction) or isSecret(barMin) or
        isSecret(barMax) or isSecret(barValue) or isSecret(accountWide) then
        return nil, nil, "protected"
    end
    if not positiveInteger(factionId) or factionId > 2147483647 then
        return nil, nil, "faction ID invalid"
    end
    if not positiveInteger(reaction) or reaction > 16 then
        return nil, nil, "reaction invalid"
    end
    if not boundedStandingValue(barMin) or not boundedStandingValue(barMax) or
        not boundedStandingValue(barValue) or barMin >= barMax or
        barValue < barMin or barValue > barMax then
        return nil, nil, "standing interval unsupported"
    end
    if type(accountWide) ~= "boolean" then
        return nil, nil, "account-wide unavailable"
    end
    return table.concat({ factionId, reaction, barMin, barMax, barValue,
        tostring(accountWide) }, ":"), accountWide and "account" or "character"
end

local function safetyScan(namespace, countName, rowName, limit, extract)
    local read, reason = namespacedProgressionMethod(namespace, rowName)
    if not read then return reason end
    local first, count, counts = {}, nil, { leaf = 0, account = 0, character = 0 }
    for pass = 1, 2 do
        local current
        current, reason = namespacedProgressionCount(namespace, countName, limit)
        if not current then return reason end
        if count and current ~= count then return "view changed" end
        count = current
        for index = 1, count do
            local signature, category, problem = extract(read, index)
            if not signature then return problem end
            if pass == 1 then
                first[index] = signature
                if category then counts[category] = counts[category] + 1 end
            elseif first[index] ~= signature then
                return "view changed"
            end
        end
    end
    return counts, count
end

function MclarionWow_ProbeProgressionSafety()
    local combat, err = combatStatus()
    if combat == nil then return nil, err end
    if combat then return nil, "Progression safety probe is unavailable during combat." end
    local quests, questRows = safetyScan(C_QuestLog, "GetNumQuestLogEntries",
        "GetInfo", 128, safetyQuestRow)
    local factions, factionRows = safetyScan(C_Reputation, "GetNumFactions",
        "GetFactionDataByIndex", 256, safetyFactionRow)
    local questSummary = type(quests) == "table" and
        string.format("stable %d/%d", quests.leaf, questRows) or quests
    local factionSummary = type(factions) == "table" and
        string.format("stable character %d, account-wide %d (%d visible rows)",
            factions.character, factions.account, factionRows) or factions
    return string.format("quest %s; reputation %s. No progression data saved.",
        questSummary, factionSummary)
end

-- Shared fail-closed scanner for explicitly requested reads of the logged-in
-- character's own purchased, currently viewable bank tabs. Account-bank IDs
-- are rejected before any slots are read. Results are never persisted here.
local function scanCharacterBank(collectTotals)
    local combat, combatError = combatStatus()
    if combat == nil then return nil, combatError end
    if combat then return nil, "Bank scan is unavailable during combat." end

    if isSecret(C_Bank) or type(C_Bank) ~= "table" or issecrettable(C_Bank) or
        isSecret(Enum) or type(Enum) ~= "table" or issecrettable(Enum) or
        isSecret(C_Container) or type(C_Container) ~= "table" or issecrettable(C_Container) then
        return nil, "Bank API is unavailable or protected by the client."
    end
    local bankTypes = Enum.BankType
    if isSecret(bankTypes) or type(bankTypes) ~= "table" or issecrettable(bankTypes) then
        return nil, "Bank type is protected by the client."
    end
    local characterType = bankTypes.Character
    if isSecret(characterType) then return nil, "Bank type is protected by the client." end
    if not nonnegativeInteger(characterType) or characterType > 10 then
        return nil, "Character bank type is unavailable."
    end
    local frame = BankFrame
    local frameType = type(frame)
    if isSecret(frame) or (frameType ~= "table" and frameType ~= "userdata") or
        (frameType == "table" and issecrettable(frame)) then
        return nil, "Character bank view is unavailable or protected by the client."
    end
    local isShown, getActiveType = frame.IsShown, frame.GetActiveBankType
    if isSecret(isShown) or isSecret(getActiveType) or
        type(isShown) ~= "function" or type(getActiveType) ~= "function" then
        return nil, "Character bank view is unavailable or protected by the client."
    end
    local shownOk, shown = pcall(isShown, frame)
    local typeOk, activeType = pcall(getActiveType, frame)
    if not shownOk or isSecret(shown) or shown ~= true or
        not typeOk or isSecret(activeType) or activeType ~= characterType then
        return nil, "Character bank view is not active."
    end

    local anyViewable, canView, fetchTabs = C_Bank.AreAnyBankTypesViewable,
        C_Bank.CanViewBank, C_Bank.FetchPurchasedBankTabData
    local getSlots, getInfo = C_Container.GetContainerNumSlots, C_Container.GetContainerItemInfo
    if isSecret(anyViewable) or isSecret(canView) or isSecret(fetchTabs) or
        isSecret(getSlots) or isSecret(getInfo) or
        type(anyViewable) ~= "function" or type(canView) ~= "function" or
        type(fetchTabs) ~= "function" or type(getSlots) ~= "function" or
        type(getInfo) ~= "function" then
        return nil, "Bank API is unavailable or protected by the client."
    end
    local any = anyViewable()
    if isSecret(any) then return nil, "Bank visibility is protected by the client." end
    if type(any) ~= "boolean" or not any then return nil, "No bank is viewable." end
    local visible = canView(characterType)
    if isSecret(visible) then return nil, "Bank visibility is protected by the client." end
    if type(visible) ~= "boolean" or not visible then return nil, "Character bank is not viewable." end

    local tabs = fetchTabs(characterType)
    if isSecret(tabs) or type(tabs) ~= "table" or issecrettable(tabs) then
        return nil, "Character bank tabs are unavailable or protected by the client."
    end
    local tabCount = 0
    for key in next, tabs do
        if isSecret(key) then return nil, "Character bank tab key is protected by the client." end
        if not positiveInteger(key) or key > 9 then
            return nil, "Character bank tabs are unsupported."
        end
        tabCount = tabCount + 1
    end
    if tabCount == 0 then return nil, "Character bank tabs are unavailable." end
    local tabIds, scannedIds = {}, {}
    for index = 1, tabCount do
        local tab = tabs[index]
        if tab == nil then return nil, "Character bank tabs are unsupported." end
        if isSecret(tab) or type(tab) ~= "table" or issecrettable(tab) then
            return nil, "Character bank tab is protected by the client."
        end
        local tabId = tab.ID
        if isSecret(tabId) then return nil, "Character bank tab ID is protected by the client." end
        -- Exact Forever 1.60.1 client BagIndex constants: character 6..14, account 15..23.
        if not nonnegativeInteger(tabId) or tabId < 6 or tabId > 14 or tabIds[tabId] then
            return nil, "Character bank tab ID is unsupported."
        end
        tabIds[tabId] = true
        scannedIds[index] = tabId
    end
    table.sort(scannedIds)

    local result = {
        tabCount = tabCount,
        slotsTotal = 0,
        occupied = 0,
        distinct = 0,
        itemIds = {},
        totalsByTab = collectTotals and {} or nil,
    }
    local seen = {}
    for _, tabId in ipairs(scannedIds) do
        local slots = getSlots(tabId)
        if isSecret(slots) then return nil, "Bank slot count is protected by the client." end
        if not nonnegativeInteger(slots) or slots > 120 then
            return nil, "Bank slot count is unavailable."
        end
        if slots == 0 then return nil, "Character bank tab slots are unavailable." end
        result.slotsTotal = result.slotsTotal + slots
        local totals = collectTotals and {} or nil
        for slot = 1, slots do
            local item = getInfo(tabId, slot)
            if isSecret(item) then return nil, "Bank item is protected by the client." end
            if item ~= nil then
                if type(item) ~= "table" or issecrettable(item) then
                    return nil, "Bank item is protected by the client."
                end
                local itemId, count = item.itemID, item.stackCount
                if isSecret(itemId) or isSecret(count) then
                    return nil, "Bank item value is protected by the client."
                end
                if not positiveInteger(itemId) or itemId > 2147483647 or
                    not positiveInteger(count) or count > 2147483647 then
                    return nil, "Bank item value is invalid."
                end
                if totals then
                    local total = (totals[itemId] or 0) + count
                    if total > 2147483647 then return nil, "Bank item total is too large." end
                    totals[itemId] = total
                end
                result.occupied = result.occupied + 1
                if not seen[itemId] then
                    seen[itemId] = true
                    result.itemIds[#result.itemIds + 1] = itemId
                    result.distinct = result.distinct + 1
                end
            end
        end
        if totals then result.totalsByTab[tabId] = totals end
    end
    table.sort(result.itemIds)
    return result
end

-- Count-only diagnostic for purchased tabs in the character's own viewable bank.
-- Only aggregate counts leave this function; item IDs, per-item counts and snapshots do not.
function MclarionWow_ProbeBank()
    local result, err = scanCharacterBank(false)
    if not result then
        if err == "Bank scan is unavailable during combat." then
            err = "Bank probe is unavailable during combat."
        end
        return nil, err
    end
    return string.format("Character bank probe: %d tabs, %d slots, %d occupied, %d distinct items. No bank data saved.",
        result.tabCount, result.slotsTotal, result.occupied, result.distinct)
end

-- Builder for item totals from purchased tabs in the character's own
-- currently viewable bank. Nothing from this scan is written to SavedVariables.
function MclarionWow_BuildBankExport()
    local result, scanError = scanCharacterBank(true)
    if not result then
        if scanError == "Bank scan is unavailable during combat." then
            scanError = "Bank export is unavailable during combat."
        end
        return nil, scanError
    end
    local entries = {}
    for tabId = 6, 14 do
        local totals = result.totalsByTab[tabId]
        local itemIds = {}
        for itemId in pairs(totals or {}) do itemIds[#itemIds + 1] = itemId end
        table.sort(itemIds)
        for _, itemId in ipairs(itemIds) do
            entries[#entries + 1] = string.format("%.0f:%.0f:%.0f", tabId, itemId, totals[itemId])
            if #entries > 1080 then return nil, "Bank export has too many entries." end
        end
    end

    if isSecret(GetServerTime) or isSecret(UnitGUID) or isSecret(GetBuildInfo) or
        type(GetServerTime) ~= "function" or type(UnitGUID) ~= "function" or
        type(GetBuildInfo) ~= "function" then
        return nil, "Bank export metadata is unavailable or protected by the client."
    end
    local timestamp, guid = GetServerTime(), UnitGUID("player")
    local _, buildString = GetBuildInfo()
    if isSecret(timestamp) or isSecret(guid) or isSecret(buildString) then
        return nil, "Bank export metadata is protected by the client."
    end
    if not positiveInteger(timestamp) or timestamp > 253402300799 or
        type(guid) ~= "string" or #guid > 80 or not guid:match("^Player%-%d+%-%x+$") or
        (type(buildString) ~= "string" and type(buildString) ~= "number") then
        return nil, "Bank export metadata is unavailable."
    end
    local build = tonumber(buildString)
    if not positiveInteger(build) or build > 2147483647 then
        return nil, "Bank export build is invalid."
    end
    local export = table.concat({ "MHWOWK1", "forever", string.format("%.0f", timestamp),
        guid, table.concat(entries, ","), string.format("%.0f", build) }, "|")
    if #export > 32768 then return nil, "Bank export is too large." end
    return export, nil, guid
end

function MclarionWow_BuildBagExport()
    local apisAvailable, apiError = exportApisAvailable(GetServerTime, UnitGUID, GetBuildInfo)
    if not apisAvailable then return nil, apiError end
    local report, totalsOrError = scanBags(true)
    if not report then return nil, totalsOrError end
    local timestamp = GetServerTime()
    local guid = UnitGUID("player")
    local _, buildString = GetBuildInfo()
    if isSecret(timestamp) or isSecret(guid) or isSecret(buildString) then
        return nil, "Bag export metadata is protected by the client."
    end
    if not positiveInteger(timestamp) or type(guid) ~= "string" or
        #guid > 80 or not guid:match("^Player%-%d+%-%x+$") or
        (type(buildString) ~= "string" and type(buildString) ~= "number") then
        return nil, "Bag export metadata is unavailable."
    end
    local build = tonumber(buildString)
    if not positiveInteger(build) or build > 2147483647 then
        return nil, "Bag export build is invalid."
    end
    local ids, entries = {}, {}
    for itemId in pairs(totalsOrError) do ids[#ids + 1] = itemId end
    table.sort(ids)
    for _, itemId in ipairs(ids) do
        entries[#entries + 1] = string.format("%.0f:%.0f", itemId, totalsOrError[itemId])
    end
    local export = table.concat({ "MHWOWB1", "forever", string.format("%.0f", timestamp),
        guid, table.concat(entries, ","), string.format("%.0f", build) }, "|")
    if #export > 16000 then return nil, "Bag export is too large." end
    return export, nil, guid
end

-- Bounded metadata for the player's own observed IDs.
-- Text is hex-encoded so item links/descriptions cannot alter the wire format.
local function itemText(value, maxBytes)
    if isSecret(value) or type(value) ~= "string" or #value > maxBytes or
        value:find("[%c]") then return nil end
    return (value:gsub(".", function(byte)
        return string.format("%02X", string.byte(byte))
    end))
end

local function itemMetadataApi(requireInventory)
    if isSecret(C_Item) or type(C_Item) ~= "table" or issecrettable(C_Item) then
        return nil, "Item API is unavailable."
    end
    local getInfo = C_Item.GetItemInfo
    if isSecret(getInfo) or (requireInventory and isSecret(GetInventoryItemID)) or isSecret(GetLocale) or
        isSecret(GetServerTime) or isSecret(UnitGUID) or isSecret(GetBuildInfo) then
        return nil, "Item export API is protected by the client."
    end
    if type(getInfo) ~= "function" or (requireInventory and type(GetInventoryItemID) ~= "function") or
        type(GetLocale) ~= "function" or type(GetServerTime) ~= "function" or
        type(UnitGUID) ~= "function" or type(GetBuildInfo) ~= "function" then
        return nil, "Item API is unavailable."
    end
    return getInfo
end

-- Shared MHWOWI1 serializer. Callers supply a sorted, bounded set of IDs from
-- their own safe scanner so bag/equipment and bank metadata cannot drift.
local function buildItemMetadataExport(sorted, getInfo)
    local timestamp, guid, locale = GetServerTime(), UnitGUID("player"), GetLocale()
    local _, buildString = GetBuildInfo()
    if isSecret(timestamp) or isSecret(guid) or isSecret(locale) or isSecret(buildString) then
        return nil, "Item export metadata is protected by the client."
    end
    local build = tonumber(buildString)
    if not positiveInteger(timestamp) or timestamp > 253402300799 or
        type(guid) ~= "string" or #guid > 80 or not guid:match("^Player%-%d+%-%x+$") or
        type(locale) ~= "string" or not locale:match("^[a-z][a-z][A-Z][A-Z]$") or
        not positiveInteger(build) or build > 2147483647 then
        return nil, "Item export metadata is invalid."
    end
    local entries = {}
    for _, id in ipairs(sorted) do
        local name, link, quality, level, minLevel, kind, subkind, stackLimit,
            equipLoc, texture, sellPrice, classId, subclassId, bindType,
            expansionId, setId, reagent, description = getInfo(id)
        local values = { name, link, quality, level, minLevel, kind, subkind,
            stackLimit, equipLoc, texture, sellPrice, classId, subclassId,
            bindType, expansionId, setId, reagent, description }
        for index = 1, 18 do
            if isSecret(values[index]) then
                return nil, "Item metadata is protected by the client."
            end
        end
        if name ~= nil then
            local text = {
                itemText(name, 160), itemText(link, 512), itemText(kind, 160),
                itemText(subkind, 160), itemText(equipLoc, 64), itemText(description, 512)
            }
            if not text[1] or text[1] == "" or not text[2] or not text[3] or
                not text[4] or not text[5] or not text[6] then
                return nil, "Item text is invalid."
            end
            local numbers = { quality, level, minLevel, stackLimit,
                texture, sellPrice, classId, subclassId, bindType, expansionId }
            for index = 1, 10 do
                local number = numbers[index]
                if not nonnegativeInteger(number) or number > 2147483647 then
                    return nil, "Item number is invalid."
                end
            end
            if setId ~= nil and (not nonnegativeInteger(setId) or setId > 2147483647) then
                return nil, "Item set ID is invalid."
            end
            if type(reagent) ~= "boolean" then return nil, "Item reagent flag is invalid." end
            entries[#entries + 1] = table.concat({
                id, text[1], text[2], quality, level, minLevel, text[3], text[4],
                stackLimit, text[5], texture, sellPrice, classId, subclassId,
                bindType, expansionId, setId or "", reagent and "1" or "0", text[6]
            }, ":")
        end -- Uncached names remain unresolved IDs on the site.
    end
    if #entries == 0 then return nil, "Item names are not available from the client cache." end
    local export = table.concat({ "MHWOWI1", "forever", string.format("%.0f", timestamp),
        guid, string.format("%.0f", build), locale, table.concat(entries, ";") }, "|")
    if #export > 32768 then return nil, "Item export is too large." end
    return export, nil, guid, #entries, #sorted
end

function MclarionWow_BuildItemExport()
    local report, totalsOrError = scanBags(true)
    if not report then return nil, totalsOrError end
    local getInfo, apiError = itemMetadataApi(true)
    if not getInfo then return nil, apiError end
    local ids = {}
    for id in pairs(totalsOrError) do ids[id] = true end
    for slot = 1, 19 do
        local id = GetInventoryItemID("player", slot)
        if isSecret(id) then return nil, "Equipped item is protected by the client." end
        if id ~= nil then
            if not positiveInteger(id) or id > 2147483647 then
                return nil, "Equipped item ID is invalid."
            end
            ids[id] = true
        end
    end
    local sorted = {}
    for id in pairs(ids) do sorted[#sorted + 1] = id end
    if #sorted > 128 then return nil, "Too many distinct own items for one export." end
    table.sort(sorted)
    return buildItemMetadataExport(sorted, getInfo)
end

function MclarionWow_BuildBankItemExport(page)
    if isSecret(page) then return nil, "Bank metadata page is protected by the client." end
    if page == nil then page = 1 end
    if not positiveInteger(page) or page > 9 then
        return nil, "Bank metadata page must be an integer from 1 to 9."
    end
    local result, scanError = scanCharacterBank(false)
    if not result then
        if scanError == "Bank scan is unavailable during combat." then
            scanError = "Bank item metadata export is unavailable during combat."
        end
        return nil, scanError
    end
    local pageSize = 128
    local pageCount = math.max(1, math.ceil(#result.itemIds / pageSize))
    if page > pageCount then
        return nil, string.format("Bank metadata page %d is unavailable; choose 1 to %d.", page, pageCount)
    end
    local pageIds = {}
    local first = (page - 1) * pageSize + 1
    local last = math.min(#result.itemIds, first + pageSize - 1)
    for index = first, last do pageIds[#pageIds + 1] = result.itemIds[index] end
    local getInfo, apiError = itemMetadataApi(false)
    if not getInfo then return nil, apiError end
    local export, exportError, guid, resolved, observed = buildItemMetadataExport(pageIds, getInfo)
    if not export then return nil, exportError end
    return export, nil, guid, page, pageCount, resolved, observed
end

-- Read-only whole-root projection. The game owns SavedVariables serialization;
-- this envelope is deliberately not presented as actual on-disk bytes.
local function estimateSavedRoot(root)
    local limit, bytes, nodes, seen = 3000000, 4096, 0, {}
    local function charge(amount)
        if amount > limit - bytes then return nil, "over budget" end
        bytes = bytes + amount
        return true
    end
    local function visit(value, depth)
        if isSecret(value) then return nil, "protected value" end
        nodes = nodes + 1
        if nodes > 50000 then return nil, "too many values" end
        local kind = type(value)
        if kind == "string" then
            return charge(4 * #value + 16)
        elseif kind == "number" then
            if value ~= value or value == math.huge or value == -math.huge or
                value ~= math.floor(value) or math.abs(value) > 9007199254740991 then
                return nil, "unsupported number"
            end
            return charge(64)
        elseif kind == "boolean" then
            return charge(16)
        elseif kind ~= "table" then
            return nil, "unsupported value"
        end
        if issecrettable(value) then return nil, "protected table" end
        if depth >= 8 then return nil, "too deep" end
        local meta = getmetatable(value)
        if isSecret(meta) or meta ~= nil then return nil, "metatable" end
        if seen[value] then return nil, "repeated table" end
        seen[value] = true
        local ok, reason = charge(128 + depth * 32)
        if not ok then return nil, reason end
        for key, child in pairs(value) do
            if isSecret(key) then return nil, "protected key" end
            nodes = nodes + 1
            if nodes > 50000 then return nil, "too many values" end
            local keyKind = type(key)
            if keyKind == "string" then
                ok, reason = charge(128 + 4 * #key)
            elseif keyKind == "number" and key > 0 and
                key <= 2147483647 and key == math.floor(key) then
                ok, reason = charge(192)
            else
                return nil, "unsupported key"
            end
            if not ok then return nil, reason end
            ok, reason = visit(child, depth + 1)
            if not ok then return nil, reason end
        end
        return true
    end
    local ok, reason = visit(root, 0)
    if not ok then return nil, reason end
    return bytes
end

-- Provisional structural envelope, not game-serialized bytes. Substitute the
-- proposed root exactly once; charge every other root, including legacy.
local function companionBudget(which, candidate)
    if combatStatus() ~= false then return nil end
    local roots = { MclarionWowData, MclarionWowQuestData,
        MclarionWowReputationData, MclarionWowWealthData,
        MclarionWowHonorTitleData }
    roots[which] = candidate
    local total = 0
    for index = 1, 5 do
        local root = roots[index]
        -- Check nil too: a client protection shim can classify nil as secret.
        if isSecret(root) then return nil end
        if root ~= nil then
            local bytes = estimateSavedRoot(root)
            if not bytes then return nil end
            total = total + bytes
            if total > 3000000 then return nil end
        end
    end
    return true
end
function MclarionWow_QuestStorageBudget(candidate) return companionBudget(2, candidate) end
function MclarionWow_ReputationStorageBudget(candidate) return companionBudget(3, candidate) end
function MclarionWow_WealthStorageBudget(candidate) return companionBudget(4, candidate) end
function MclarionWow_HonorTitleStorageBudget(candidate) return companionBudget(5, candidate) end

-- Build an isolated schema-3 skeleton from the current schema-2 root. This is
-- a dry run only: progression stays empty, both future capture flags stay off,
-- and the returned graph is never assigned to SavedVariables.
local function cloneSavedGraph(value, depth, seen, state)
    if isSecret(value) then return nil, "protected value" end
    state.nodes = state.nodes + 1
    if state.nodes > 50000 then return nil, "too many values" end
    local kind = type(value)
    if kind == "string" or kind == "boolean" then return value end
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge or
            value ~= math.floor(value) or math.abs(value) > 9007199254740991 then
            return nil, "unsupported number"
        end
        return value
    end
    if kind ~= "table" then return nil, "unsupported value" end
    if issecrettable(value) then return nil, "protected table" end
    if depth >= 8 then return nil, "too deep" end
    local meta = getmetatable(value)
    if isSecret(meta) or meta ~= nil then return nil, "metatable" end
    if seen[value] then return nil, "repeated table" end
    seen[value] = true
    local result = {}
    for key, child in pairs(value) do
        if isSecret(key) then return nil, "protected key" end
        local keyKind = type(key)
        if keyKind ~= "string" and (keyKind ~= "number" or key <= 0 or
            key > 2147483647 or key ~= math.floor(key)) then
            return nil, "unsupported key"
        end
        local copied, reason = cloneSavedGraph(child, depth + 1, seen, state)
        if copied == nil then return nil, reason end
        result[key] = copied
    end
    return result
end

local function migrationTable(value, label, optional)
    if isSecret(value) or (type(value) == "table" and issecrettable(value)) then
        return nil, "Saved " .. label .. " is protected by the client."
    end
    if value == nil and optional then return true end
    if type(value) ~= "table" then
        return nil, "Saved " .. label .. " has an unsupported format."
    end
    local meta = getmetatable(value)
    if isSecret(meta) or meta ~= nil then
        return nil, "Saved " .. label .. " has a metatable."
    end
    return true
end

local validItemPayload -- shared with the existing schema-2 item writer below

local function migrationItemRecords(items)
    local owners, bytes = 0, 0
    for owner, record in pairs(items) do
        if type(owner) ~= "string" or #owner > 77 or
            not owner:match("^Player%-[A-Za-z0-9%-]+$") or
            type(record) ~= "table" then return false end
        owners = owners + 1
        if owners > 256 then return false end
        local fields = 0
        for source, value in pairs(record) do
            fields = fields + 1
            if source == "bags" then
                if not validItemPayload(value, owner) then return false end
                bytes = bytes + #value
            elseif source == "bank" then
                if type(value) ~= "table" then return false end
                local pages = 0
                for page, payload in pairs(value) do
                    if type(page) ~= "number" or page < 1 or page > 9 or
                        page ~= math.floor(page) or
                        not validItemPayload(payload, owner) then return false end
                    pages = pages + 1
                    bytes = bytes + #payload
                end
                if pages == 0 then return false end
                for page = 1, pages do
                    if rawget(value, page) == nil then return false end
                end
            else
                return false
            end
            if bytes > 1048576 then return false end
        end
        if fields == 0 then return false end
    end
    return true
end

local function buildSchema3DryRun()
    local combat, combatError = combatStatus()
    if combat == nil then return nil, nil, combatError end
    if combat then return nil, nil, "Migration preflight is unavailable during combat." end
    local source = MclarionWowData
    local ok, reason = migrationTable(source, "root")
    if not ok then return nil, nil, reason end
    local schema = rawget(source, "schema")
    if isSecret(schema) then return nil, nil, "Saved schema is protected by the client." end
    if schema ~= 2 then return nil, nil, "Migration preflight requires schema 2." end
    local progression = rawget(source, "progression")
    if isSecret(progression) then
        return nil, nil, "Saved progression is protected by the client."
    end
    if progression ~= nil then
        return nil, nil, "Saved data already has a progression root."
    end
    local allowedRoot = { schema = true, settings = true, characters = true,
        bags = true, bank = true, items = true }
    for key in pairs(source) do
        if isSecret(key) then return nil, nil, "Saved root key is protected by the client." end
        if not allowedRoot[key] then return nil, nil, "Saved root key is unsupported." end
    end
    local characters = rawget(source, "characters")
    ok, reason = migrationTable(characters, "character data")
    if not ok then return nil, nil, reason end
    local items = rawget(source, "items")
    ok, reason = migrationTable(items, "item details")
    if not ok then return nil, nil, reason end
    for _, field in ipairs({ "bags", "bank" }) do
        ok, reason = migrationTable(rawget(source, field), field .. " data", true)
        if not ok then return nil, nil, reason end
    end
    local settings = rawget(source, "settings")
    ok, reason = migrationTable(settings, "settings", true)
    if not ok then return nil, nil, reason end
    if settings ~= nil then
        local questFlag = rawget(settings, "autoQuestCapture")
        local reputationFlag = rawget(settings, "autoReputationCapture")
        if isSecret(questFlag) or isSecret(reputationFlag) then
            return nil, nil, "Saved migration settings are protected by the client."
        end
        if questFlag ~= nil or reputationFlag ~= nil then
            return nil, nil, "Saved migration settings already exist."
        end
        local allowedSetting = { autoCombatLog = true, autoCharacterCapture = true,
            autoBagCapture = true, autoBankCapture = true,
            autoItemMetadataCapture = true }
        for key, value in pairs(settings) do
            if isSecret(key) or isSecret(value) then
                return nil, nil, "Saved settings are protected by the client."
            end
            if not allowedSetting[key] or type(value) ~= "boolean" then
                return nil, nil, "Saved setting has an unsupported format."
            end
        end
    end
    local sourceSize, sizeReason = estimateSavedRoot(source)
    if not sourceSize then
        return nil, nil, "Schema-2 source refused (" .. sizeReason .. ")."
    end
    local candidate, cloneReason = cloneSavedGraph(source, 0, {}, { nodes = 0 })
    if not candidate then return nil, nil, "Schema-2 clone refused (" .. cloneReason .. ")." end
    if not migrationItemRecords(candidate.items) then
        return nil, nil, "Schema-2 item records have an unsupported format."
    end
    candidate.schema = 3
    if candidate.settings == nil then candidate.settings = {} end
    candidate.settings.autoQuestCapture = false
    candidate.settings.autoReputationCapture = false
    candidate.progression = {}
    local projected, projectedReason = estimateSavedRoot(candidate)
    if not projected then
        return nil, nil, "Schema-3 candidate refused (" .. projectedReason .. ")."
    end
    return candidate, projected
end

function MclarionWow_ProbeSchema3Preflight()
    local _, projected, reason = buildSchema3DryRun()
    if not projected then return nil, reason end
    return string.format("Schema-3 dry-run projected %d/3000000 bytes " ..
        "(not actual file bytes; item records checked, other legacy histories not validated). " ..
        "No data saved.", projected)
end

function MclarionWow_ProbeSavedSize()
    local combat, err = combatStatus()
    if combat == nil then return nil, err end
    if combat then return nil, "Size probe is unavailable during combat." end
    local data = MclarionWowData
    if isSecret(data) then return nil, "Saved data is protected by the client." end
    if type(data) ~= "table" or issecrettable(data) then
        return nil, "Saved data is unavailable or protected."
    end
    local meta = getmetatable(data)
    if isSecret(meta) or meta ~= nil then return nil, "Saved data has a metatable." end
    local schema = rawget(data, "schema")
    if isSecret(schema) then return nil, "Saved schema is protected by the client." end
    if schema ~= 1 and schema ~= 2 then return nil, "Saved schema is unsupported." end
    local size, reason = estimateSavedRoot(data)
    if not size then return nil, "Whole-save projection refused (" .. reason .. "). No data saved." end
    return string.format("Whole-save projected %d/3000000 bytes (not actual file bytes). No data saved.", size)
end

local function storageRoot()
    if type(issecretvalue) ~= "function" or type(issecrettable) ~= "function" then
        return nil, "Saved data protection checks are unavailable."
    end
    local data = MclarionWowData
    if isSecret(data) or (type(data) == "table" and issecrettable(data)) then
        return nil, "Saved data is protected by the client; it was not overwritten."
    end
    if data == nil then
        data = { schema = 1, characters = {} }
        MclarionWowData = data
    end
    if type(data) ~= "table" then
        return nil, "Saved data has an unsupported format; it was not overwritten."
    end
    local schema = data.schema
    if isSecret(schema) then
        return nil, "Saved data schema is protected by the client; it was not overwritten."
    end
    if schema ~= 1 and schema ~= 2 then
        return nil, "Saved data has an unsupported format; it was not overwritten."
    end
    local characters = data.characters
    if isSecret(characters) or (type(characters) == "table" and issecrettable(characters)) then
        return nil, "Saved character data is protected by the client; it was not overwritten."
    end
    if type(characters) ~= "table" then
        return nil, "Saved data has an unsupported format; it was not overwritten."
    end
    if schema == 2 and (isSecret(data.items) or type(data.items) ~= "table" or
        issecrettable(data.items)) then
        return nil, "Saved item details have an unsupported format; they were not overwritten."
    end
    return data, nil, characters
end

local function settingsRoot()
    local data, err = storageRoot()
    if not data then return nil, err end
    local settings = data.settings
    if isSecret(settings) or (type(settings) == "table" and issecrettable(settings)) then
        return nil, "Addon settings are protected by the client."
    end
    if settings == nil then
        settings = { autoCombatLog = false, autoCharacterCapture = false,
            autoBagCapture = false, autoBankCapture = false }
        data.settings = settings
    end
    if type(settings) ~= "table" or isSecret(settings.autoCombatLog) or
        isSecret(settings.autoCharacterCapture) or isSecret(settings.autoBagCapture) or
        isSecret(settings.autoBankCapture) or isSecret(settings.autoItemMetadataCapture) or
        type(settings.autoCombatLog) ~= "boolean" or
        type(settings.autoBagCapture) ~= "boolean" or
        (settings.autoCharacterCapture ~= nil and type(settings.autoCharacterCapture) ~= "boolean") or
        (settings.autoBankCapture ~= nil and type(settings.autoBankCapture) ~= "boolean") or
        (settings.autoItemMetadataCapture ~= nil and
            type(settings.autoItemMetadataCapture) ~= "boolean") then
        return nil, "Addon settings have an unsupported format; they were not overwritten."
    end
    if settings.autoCharacterCapture == nil then settings.autoCharacterCapture = false end
    if settings.autoBankCapture == nil then settings.autoBankCapture = false end
    return settings
end

local function validateHistory(snapshots, label)
    local count = #snapshots
    if count > 20 then
        return nil, "Saved " .. label .. " history exceeds the limit; it was not overwritten."
    end
    local found = 0
    for key, entry in pairs(snapshots) do
        if isSecret(key) or isSecret(entry) or
            (type(key) == "table" and issecrettable(key)) or
            (type(entry) == "table" and issecrettable(entry)) then
            return nil, "Saved " .. label .. " history is protected by the client; it was not overwritten."
        end
        if type(key) ~= "number" or key ~= math.floor(key) or key < 1 or key > count or
            type(entry) ~= "string" then
            return nil, "Saved " .. label .. " history has an unsupported format; it was not overwritten."
        end
        found = found + 1
    end
    if found ~= count then
        return nil, "Saved " .. label .. " history has an unsupported format; it was not overwritten."
    end
    return count
end

local function saveSnapshot(guid, export)
    local _, storageError, characters = storageRoot()
    if storageError then return nil, storageError end
    local snapshots = characters[guid]
    if isSecret(snapshots) or (type(snapshots) == "table" and issecrettable(snapshots)) then
        return nil, "Saved character history is protected by the client; it was not overwritten."
    end
    if snapshots == nil then
        snapshots = {}
        characters[guid] = snapshots
    elseif type(snapshots) ~= "table" then
        return nil, "Saved character history has an unsupported format; it was not overwritten."
    end
    local count, historyError = validateHistory(snapshots, "character")
    if historyError then return nil, historyError end
    -- Time alone is not a meaningful character change. Keep local history bounded
    -- even when the periodic capture runs for hours without gear/zone changes.
    local details = export:match("^MHWOW[12]|forever|%d+|(.*)$")
    local last = snapshots[count]
    local previous = last and last:match("^MHWOW[12]|forever|%d+|(.*)$")
    if last ~= export and (details == nil or details ~= previous) then
        snapshots[#snapshots + 1] = export
        if #snapshots > 20 then
            table.remove(snapshots, 1)
        end
    end
    return true
end

local function saveBagSnapshot(guid, export, explicit)
    local data, storageError = storageRoot()
    if not data then return nil, storageError end
    local bagMap = data.bags
    if isSecret(bagMap) or (type(bagMap) == "table" and issecrettable(bagMap)) then
        return nil, "Saved bag data is protected by the client; it was not overwritten."
    end
    if bagMap == nil then
        bagMap = {}
        data.bags = bagMap
    end
    if type(bagMap) ~= "table" then
        return nil, "Saved bag data has an unsupported format; it was not overwritten."
    end
    local snapshots = bagMap[guid]
    if isSecret(snapshots) or (type(snapshots) == "table" and issecrettable(snapshots)) then
        return nil, "Saved bag history is protected by the client; it was not overwritten."
    end
    if snapshots == nil then
        snapshots = {}
        bagMap[guid] = snapshots
    elseif type(snapshots) ~= "table" then
        return nil, "Saved bag history has an unsupported format; it was not overwritten."
    end
    local details = export:match("^MHWOWB1|forever|%d+|(.*)$")
    local count, historyError = validateHistory(snapshots, "bag")
    if historyError then return nil, historyError end
    local last = snapshots[count]
    if not details then
        return nil, "Saved bag history has an unsupported format; it was not overwritten."
    end
    local previous = last and last:match("^MHWOWB1|forever|%d+|(.*)$")
    local currentItems = export:match("^MHWOWB1|forever|%d+|[^|]+|([^|]*)|%d+$")
    local previousItems = last and last:match("^MHWOWB1|forever|%d+|[^|]+|([^|]*)|%d+$")
    if currentItems == "" and previousItems and previousItems ~= "" and not explicit then
        return nil, "Empty bag scan needs explicit confirmation."
    end
    if details ~= previous then
        snapshots[#snapshots + 1] = export
        if #snapshots > 20 then table.remove(snapshots, 1) end
    end
    return true
end

local function saveBankSnapshot(guid, export, explicit)
    local data, storageError = storageRoot()
    if not data then return nil, storageError end
    local bankMap = data.bank
    if isSecret(bankMap) or (type(bankMap) == "table" and issecrettable(bankMap)) then
        return nil, "Saved bank data is protected by the client; it was not overwritten."
    end
    if bankMap == nil then
        bankMap = {}
        data.bank = bankMap
    end
    if type(bankMap) ~= "table" then
        return nil, "Saved bank data has an unsupported format; it was not overwritten."
    end
    local snapshots = bankMap[guid]
    if isSecret(snapshots) or (type(snapshots) == "table" and issecrettable(snapshots)) then
        return nil, "Saved bank history is protected by the client; it was not overwritten."
    end
    if snapshots == nil then
        snapshots = {}
        bankMap[guid] = snapshots
    elseif type(snapshots) ~= "table" then
        return nil, "Saved bank history has an unsupported format; it was not overwritten."
    end
    local count, historyError = validateHistory(snapshots, "bank")
    if historyError then return nil, historyError end
    local details = export:match("^MHWOWK1|forever|%d+|(.*)$")
    if not details then return nil, "Saved bank export has an unsupported format." end
    local last = snapshots[count]
    local previous = last and last:match("^MHWOWK1|forever|%d+|(.*)$")
    local currentItems = export:match("^MHWOWK1|forever|%d+|[^|]+|([^|]*)|%d+$")
    local previousItems = last and last:match("^MHWOWK1|forever|%d+|[^|]+|([^|]*)|%d+$")
    if currentItems and not currentItems:find(":%d+:%d+") and previousItems and
        previousItems:find(":%d+:%d+") and not explicit then
        return nil, "Empty bank scan needs explicit confirmation."
    end
    if details ~= previous then
        snapshots[#snapshots + 1] = export
        if #snapshots > 20 then table.remove(snapshots, 1) end
    end
    return true
end

-- One latest copy per source; older numeric histories remain unchanged.
validItemPayload = function(value, guid)
    if isSecret(value) or type(value) ~= "string" or #value > 32768 then return false end
    local stamp, owner, build, locale, entries =
        value:match("^MHWOWI1|forever|(%d+)|([^|]+)|(%d+)|([^|]+)|([^|]+)$")
    if owner ~= guid or not positiveInteger(tonumber(stamp)) or
        tonumber(stamp) > 253402300799 or not positiveInteger(tonumber(build)) or
        tonumber(build) > 2147483647 or
        not locale:match("^[a-z][a-z][A-Z][A-Z]$") or
        entries:sub(1, 1) == ";" or entries:sub(-1) == ";" or
        entries:find(";;", 1, true) then return false end
    local function number(text, optional)
        if optional and text == "" then return true end
        return text:match("^%d+$") ~= nil and tonumber(text) <= 2147483647
    end
    local function hex(text, maxBytes, required)
        return (not required or text ~= "") and #text <= maxBytes * 2 and
            #text % 2 == 0 and text:match("^[0-9A-F]*$") ~= nil
    end
    local count, previousId = 0, 0
    for entry in entries:gmatch("[^;]+") do
        count = count + 1
        if count > 128 then return false end
        local fields = {}
        for field in (entry .. ":"):gmatch("(.-):") do
            fields[#fields + 1] = field
            if #fields > 19 then return false end
        end
        local id = tonumber(fields[1])
        if #fields ~= 19 or not number(fields[1]) or not id or id <= previousId or
            not hex(fields[2], 160, true) or not hex(fields[3], 512) or
            not hex(fields[7], 160) or not hex(fields[8], 160) or
            not hex(fields[10], 64) or not hex(fields[19], 512) or
            fields[18] ~= "0" and fields[18] ~= "1" then return false end
        for _, index in ipairs({ 4, 5, 6, 9, 11, 12, 13, 14, 15, 16, 17 }) do
            if not number(fields[index], index == 17) then return false end
        end
        previousId = id
    end
    return count > 0
end

local function saveItemMetadata(guid, source, payload)
    local data, err = storageRoot()
    if not data then return nil, err end
    if isSecret(guid) or type(guid) ~= "string" or #guid > 77 or
        not guid:match("^Player%-[A-Za-z0-9%-]+$") then
        return nil, "Item details have an invalid character ID."
    end
    local items = data.items
    if data.schema == 1 then
        if items ~= nil then return nil, "Old storage has unexpected item details." end
        items = {}
    end
    local current = items[guid]
    if isSecret(current) or (type(current) == "table" and issecrettable(current)) or
        (current ~= nil and type(current) ~= "table") then
        return nil, "Saved item details are protected or malformed."
    end
    local updated = { bags = current and current.bags or nil,
        bank = current and current.bank or nil }
    updated[source] = payload
    local bytes, records = 0, 0
    for owner, record in pairs(items) do
        if isSecret(owner) or isSecret(record) or type(owner) ~= "string" or
            #owner > 77 or not owner:match("^Player%-[A-Za-z0-9%-]+$") or
            type(record) ~= "table" or issecrettable(record) then
            return nil, "Saved item details are protected or malformed."
        end
        records = records + 1
    end
    if not current then records = records + 1 end
    if records > 256 then return nil, "Item detail record limit reached." end
    local function checkRecord(owner, record)
        local fields = 0
        for key, value in pairs(record) do
            if isSecret(key) or isSecret(value) or
                (key ~= "bags" and key ~= "bank") then
                return false
            end
            fields = fields + 1
            if key == "bags" then
                if not validItemPayload(value, owner) then return false end
                bytes = bytes + #value
            else
                if type(value) ~= "table" or issecrettable(value) then return false end
                local count = 0
                for page, text in pairs(value) do
                    if isSecret(page) or type(page) ~= "number" or page < 1 or
                        page > 9 or page ~= math.floor(page) or
                        not validItemPayload(text, owner) then return false end
                    count = count + 1
                    bytes = bytes + #text
                end
                if count == 0 or count ~= #value then return false end
            end
            if bytes > 1048576 then return false end
        end
        return fields > 0
    end
    if current and not checkRecord(guid, current) then
        return nil, "Saved item details exceed the limit or are malformed."
    end
    bytes = 0 -- The replacement is charged only once, after validating the old record.
    for owner, record in pairs(items) do
        if owner ~= guid and not checkRecord(owner, record) then
            return nil, "Saved item details exceed the limit or are malformed."
        end
    end
    if not checkRecord(guid, updated) then
        return nil, "Item details exceed the limit or are malformed."
    end
    local function sameDetails(old, new)
        if not old or not new then return old == new end
        local prior = old:match("^MHWOWI1|forever|%d+|(.*)$")
        local nextValue = new:match("^MHWOWI1|forever|%d+|(.*)$")
        return prior ~= nil and prior == nextValue
    end
    local unchanged = source == "bags" and sameDetails(current and current.bags, payload)
    if source == "bank" and current and current.bank then
        unchanged = #current.bank == #payload
        for page = 1, #payload do
            if not sameDetails(current.bank[page], payload[page]) then unchanged = false end
        end
    end
    if unchanged then return true end
    -- Only mutate after validating every existing record and the full new payload.
    items[guid] = updated
    if data.schema == 1 then
        data.items = items
        data.schema = 2
    end
    return true
end

local settingsWindow, characterStatusLabel, combatStatusLabel, bagStatusLabel, bankStatusLabel, itemStatusLabel, questStatusLabel, reputationStatusLabel
local goldStatusLabel, currencyStatusLabel, honorStatusLabel, titleStatusLabel
local goldMessage = "No money observation this session."
local currencyMessage = "No visible currency observation this session."
local honorMessage = "No supported PvP observation this session."
local titleMessage = "No selected-title observation this session."
local captureNow
local inWorld = false
local characterMessage = "No character scan this session."
local combatMessage = "Waiting for the next login."
local bagMessage = "No bag capture this session."
local bankMessage = "No own-bank capture this session."
local itemMessage = "Off; enable item details to capture cached names."
local questMessage = "No active quest-log observation this session."
local reputationMessage = "No visible reputation observation this session."

local function refreshSettingsStatus()
    if characterStatusLabel then characterStatusLabel:SetText("Character: " .. characterMessage) end
    if combatStatusLabel then combatStatusLabel:SetText("Combat log: " .. combatMessage) end
    if bagStatusLabel then bagStatusLabel:SetText("Bags: " .. bagMessage) end
    if bankStatusLabel then bankStatusLabel:SetText("Bank: " .. bankMessage) end
    if itemStatusLabel then itemStatusLabel:SetText("Items: " .. itemMessage) end
    if questStatusLabel then
        questStatusLabel:SetText("Quests: " .. (type(MclarionWow_CaptureQuests) == "function" and
            questMessage or "Companion addon unavailable; install/enable MclarionWowProgression."))
    end
    if reputationStatusLabel then
        reputationStatusLabel:SetText("Reputation: " .. (type(MclarionWow_CaptureReputation) == "function" and
            reputationMessage or "Companion addon unavailable; install/enable MclarionWowProgression."))
    end
    if goldStatusLabel then goldStatusLabel:SetText("Gold: " .. (type(MclarionWow_CaptureGold) == "function" and
        goldMessage or "Companion addon unavailable; install/enable MclarionWowProgression.")) end
    if currencyStatusLabel then currencyStatusLabel:SetText("Currencies: " .. (type(MclarionWow_CaptureCurrency) == "function" and
        currencyMessage or "Companion addon unavailable; install/enable MclarionWowProgression.")) end
    if honorStatusLabel then honorStatusLabel:SetText("Honor: " .. (type(MclarionWow_CaptureHonor) == "function" and
        honorMessage or "Companion addon unavailable; install/enable MclarionWowProgression.")) end
    if titleStatusLabel then titleStatusLabel:SetText("Titles: " .. (type(MclarionWow_CaptureTitle) == "function" and
        titleMessage or "Companion addon unavailable; install/enable MclarionWowProgression.")) end
end

local function reportLoggingAfterOptOut()
    if isSecret(LoggingCombat) or type(LoggingCombat) ~= "function" then
        combatMessage = "Auto-start off; current logging status unavailable."
    else
        local checked, active = pcall(LoggingCombat)
        if checked and not isSecret(active) and type(active) == "boolean" then
            combatMessage = active and "Auto-start off; log still on. Use Stop logging now." or
                "Off; auto-start disabled."
        else
            combatMessage = "Auto-start off; current logging status unavailable."
        end
    end
    refreshSettingsStatus()
end

local function stopLoggingNow()
    if isSecret(LoggingCombat) or type(LoggingCombat) ~= "function" then
        combatMessage = "Stop unavailable: client protects the logging API."
    else
        local checked, active = pcall(LoggingCombat)
        if not checked or isSecret(active) or type(active) ~= "boolean" then
            combatMessage = "Stop unavailable: logging status is protected."
        elseif not active then
            combatMessage = "Off; auto-start disabled."
        else
            local stopped = pcall(LoggingCombat, false)
            local verified, stillActive = pcall(LoggingCombat)
            combatMessage = stopped and verified and not isSecret(stillActive) and stillActive == false and
                "Off; auto-start disabled." or "Stop unavailable: client refused; log may still be on."
        end
    end
    refreshSettingsStatus()
end

local function createSettingsWindow()
    settingsWindow = CreateFrame("Frame", "MclarionWowSettingsFrame", UIParent, "BasicFrameTemplateWithInset")
    settingsWindow:SetSize(490, 630)
    settingsWindow:SetPoint("CENTER")
    settingsWindow:SetFrameStrata("DIALOG")
    settingsWindow:SetMovable(true)
    settingsWindow:EnableMouse(true)
    settingsWindow:RegisterForDrag("LeftButton")
    settingsWindow:SetScript("OnDragStart", settingsWindow.StartMoving)
    settingsWindow:SetScript("OnDragStop", settingsWindow.StopMovingOrSizing)
    -- Two pages keep all labels/actions inside the existing readable window.
    local legacyWidgets, companionWidgets = {}, {}
    local function legacyFrame(kind, name, parent, template)
        local widget = CreateFrame(kind, name, parent, template)
        legacyWidgets[#legacyWidgets + 1] = widget
        return widget
    end
    local function legacyText(layer, style, font)
        local widget = settingsWindow:CreateFontString(layer, style, font)
        legacyWidgets[#legacyWidgets + 1] = widget
        return widget
    end
    local function companion(widget)
        companionWidgets[#companionWidgets + 1] = widget
        return widget
    end

    local title = legacyText(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -10)
    title:SetText("Vaultkeeper companion")
    local note = legacyText(nil, "OVERLAY", "GameFontNormal")
    note:SetPoint("TOPLEFT", 18, -37)
    note:SetText("Auto-capture works with this window closed; loot and bag changes scan.")
    local bankNote = legacyText(nil, "OVERLAY", "GameFontNormal")
    bankNote:SetPoint("TOPLEFT", 18, -55)
    bankNote:SetText("Open your character-bank tab for bank scans; /reload saves to disk.")

    local function checkbox(label, y, key)
        local button = legacyFrame("CheckButton", nil, settingsWindow, "UICheckButtonTemplate")
        button:SetPoint("TOPLEFT", 18, y)
        local text = legacyText(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", button, "RIGHT", 4, 0)
        text:SetText(label)
        local settings = settingsRoot()
        button:SetChecked(settings and settings[key] or false)
        button:SetScript("OnClick", function(self)
            local current = settingsRoot()
            if not current then self:SetChecked(false); return end
            current[key] = self:GetChecked() == true
            if key == "autoItemMetadataCapture" then
                itemMessage = current[key] and "Waiting for a bag/equipment or own-bank scan." or
                    "Off; enable item details to capture cached names."
                refreshSettingsStatus()
            end
            if key == "autoCombatLog" then
                if current[key] then
                    combatMessage = "Will auto-start on next world entry."
                    refreshSettingsStatus()
                else
                    reportLoggingAfterOptOut()
                end
            end
        end)
        return button
    end
    local combatCheckbox = checkbox("Enable WoW combat logging at login", -87, "autoCombatLog")
    checkbox("Capture own character state, out of combat", -118, "autoCharacterCapture")
    checkbox("Capture own bag changes, out of combat", -149, "autoBagCapture")
    checkbox("Capture own bank while open, out of combat", -180, "autoBankCapture")
    checkbox("Capture own item details (cached names only)", -211, "autoItemMetadataCapture")
    local questCheckbox = legacyFrame("CheckButton", nil, settingsWindow, "UICheckButtonTemplate")
    questCheckbox:SetPoint("TOPLEFT", 18, -242)
    local questText = legacyText(nil, "OVERLAY", "GameFontNormal")
    questText:SetPoint("LEFT", questCheckbox, "RIGHT", 4, 0)
    questText:SetText("Auto-capture active quest-log observations (off by default)")
    questCheckbox:SetChecked(type(MclarionWow_QuestAutoEnabled) == "function" and
        MclarionWow_QuestAutoEnabled() or false)
    questCheckbox:SetScript("OnClick", function(self)
        local enabled = false
        if type(MclarionWow_QuestAutoEnabled) == "function" then
            local checked, value = pcall(MclarionWow_QuestAutoEnabled)
            enabled = checked and value == true
        end
        local ok = false
        if type(MclarionWow_SetAutoQuestCapture) == "function" then
            local called, result = pcall(MclarionWow_SetAutoQuestCapture, self:GetChecked() == true)
            ok = called and result == true
        end
        if not ok then
            self:SetChecked(enabled)
            questMessage = "Setting refused; previous preference preserved."
        else
            questMessage = self:GetChecked() and "Automatic capture enabled." or
                "Automatic capture off; Quests now is still available."
        end
        refreshSettingsStatus()
    end)

    local reputationCheckbox = legacyFrame("CheckButton", nil, settingsWindow, "UICheckButtonTemplate")
    reputationCheckbox:SetPoint("TOPLEFT", 18, -268)
    local reputationText = legacyText(nil, "OVERLAY", "GameFontNormal")
    reputationText:SetPoint("LEFT", reputationCheckbox, "RIGHT", 4, 0)
    reputationText:SetText("Auto-capture visible reputation (off by default)")
    reputationCheckbox:SetChecked(type(MclarionWow_ReputationAutoEnabled) == "function" and
        MclarionWow_ReputationAutoEnabled() or false)
    reputationCheckbox:SetScript("OnClick", function(self)
        local enabled = false
        if type(MclarionWow_ReputationAutoEnabled) == "function" then
            local checked, value = pcall(MclarionWow_ReputationAutoEnabled)
            enabled = checked and value == true
        end
        local ok = false
        if type(MclarionWow_SetAutoReputationCapture) == "function" then
            local called, result = pcall(MclarionWow_SetAutoReputationCapture, self:GetChecked() == true)
            ok = called and result == true
        end
        if not ok then
            self:SetChecked(enabled)
            reputationMessage = "Setting refused; previous preference preserved."
        else
            reputationMessage = self:GetChecked() and "Automatic capture enabled." or
                "Automatic capture off; Reputation now is still available."
        end
        refreshSettingsStatus()
    end)
    characterStatusLabel = legacyText(nil, "OVERLAY", "GameFontHighlight")
    characterStatusLabel:SetPoint("TOPLEFT", 18, -304)
    combatStatusLabel = legacyText(nil, "OVERLAY", "GameFontHighlight")
    combatStatusLabel:SetPoint("TOPLEFT", 18, -326)
    bagStatusLabel = legacyText(nil, "OVERLAY", "GameFontHighlight")
    bagStatusLabel:SetPoint("TOPLEFT", 18, -348)
    bankStatusLabel = legacyText(nil, "OVERLAY", "GameFontHighlight")
    bankStatusLabel:SetPoint("TOPLEFT", 18, -370)
    itemStatusLabel = legacyText(nil, "OVERLAY", "GameFontHighlight")
    itemStatusLabel:SetPoint("TOPLEFT", 18, -392)
    questStatusLabel = legacyText(nil, "OVERLAY", "GameFontHighlight")
    questStatusLabel:SetPoint("TOPLEFT", 18, -414)
    reputationStatusLabel = legacyText(nil, "OVERLAY", "GameFontHighlight")
    reputationStatusLabel:SetPoint("TOPLEFT", 18, -436)
    refreshSettingsStatus()
    for index, entry in ipairs({ { "Character now", "character" }, { "Bags now", "bags" },
        { "Bank now", "bank" }, { "Items now", "items" } }) do
        local button = legacyFrame("Button", nil, settingsWindow, "UIPanelButtonTemplate")
        button:SetSize(110, 25)
        button:SetPoint("TOPLEFT", 18 + (index - 1) * 117, -464)
        button:SetText(entry[1])
        button:SetScript("OnClick", function()
            if not captureNow then return end
            local ok = pcall(captureNow, entry[2])
            if not ok then
                local message = "Capture unavailable: client refused requested scan."
                if entry[2] == "character" then characterMessage = message
                elseif entry[2] == "bags" then bagMessage = message
                elseif entry[2] == "bank" then bankMessage = message
                else itemMessage = message end
                refreshSettingsStatus()
            end
        end)
    end
    local questsNow = legacyFrame("Button", nil, settingsWindow, "UIPanelButtonTemplate")
    questsNow:SetSize(110, 25)
    questsNow:SetPoint("TOPLEFT", 18, -496)
    questsNow:SetText("Quests now")
    questsNow:SetScript("OnClick", function()
        if not inWorld then
            questMessage = "Unavailable before world entry."
        elseif type(MclarionWow_CaptureQuests) ~= "function" then
            questMessage = "Companion addon unavailable; install/enable MclarionWowProgression."
        else
            local ok, stored, result = pcall(MclarionWow_CaptureQuests, true)
            if not ok or stored ~= true then
                questMessage = "Capture refused; prior observations preserved."
            elseif result == "saved" then
                questMessage = "Scanned; held in memory until WoW saves."
            elseif result == "unchanged" then
                questMessage = "Scanned; unchanged."
            else questMessage = "Changed state waits for a later server second." end
        end
        refreshSettingsStatus()
    end)
    local reputationNow = legacyFrame("Button", nil, settingsWindow, "UIPanelButtonTemplate")
    reputationNow:SetSize(125, 25)
    reputationNow:SetPoint("TOPLEFT", 140, -496)
    reputationNow:SetText("Reputation now")
    reputationNow:SetScript("OnClick", function()
        if not inWorld then
            reputationMessage = "Unavailable before world entry."
        elseif type(MclarionWow_CaptureReputation) ~= "function" then
            reputationMessage = "Companion addon unavailable; install/enable MclarionWowProgression."
        else
            local ok, stored, result = pcall(MclarionWow_CaptureReputation, true)
            if not ok or stored ~= true then
                reputationMessage = "Capture refused; prior observations preserved."
            elseif result == "saved" then
                reputationMessage = "Scanned; held in memory until WoW saves."
            elseif result == "unchanged" then
                reputationMessage = "Scanned; unchanged."
            else reputationMessage = "Changed state waits for a later server second." end
        end
        refreshSettingsStatus()
    end)
    local stopButton = legacyFrame("Button", nil, settingsWindow, "UIPanelButtonTemplate")
    stopButton:SetSize(175, 25)
    stopButton:SetPoint("TOPLEFT", 18, -530)
    stopButton:SetText("Stop logging now")
    stopButton:SetScript("OnClick", function()
        local current = settingsRoot()
        if not current then
            combatMessage = "Stop unavailable: addon settings were refused."
            refreshSettingsStatus()
            return
        end
        current.autoCombatLog = false
        combatCheckbox:SetChecked(false)
        stopLoggingNow()
    end)
    local footer = legacyText(nil, "OVERLAY", "GameFontNormal")
    footer:SetPoint("TOPLEFT", 18, -567)
    footer:SetText("Stop logging now may end logging started outside this addon.")
    local saveNote = legacyText(nil, "OVERLAY", "GameFontNormal")
    saveNote:SetPoint("TOPLEFT", 18, -589)
    saveNote:SetText("Items now: bags + gear; Bank now: bank items if enabled.")

    local categories = {
        {label="Gold", plural="Gold", capture="MclarionWow_CaptureGold",
            enabled="MclarionWow_GoldAutoEnabled", setting="MclarionWow_SetAutoGoldCapture",
            description="Auto-capture own money balance (off by default)"},
        {label="Currencies", plural="Currency", capture="MclarionWow_CaptureCurrency",
            enabled="MclarionWow_CurrencyAutoEnabled", setting="MclarionWow_SetAutoCurrencyCapture",
            description="Auto-capture visible currencies (off by default)"},
        {label="Honor", plural="Honor", capture="MclarionWow_CaptureHonor",
            enabled="MclarionWow_HonorAutoEnabled", setting="MclarionWow_SetAutoHonorCapture",
            description="Auto-capture supported PvP counters (off by default)"},
        {label="Titles", plural="Title", capture="MclarionWow_CaptureTitle",
            enabled="MclarionWow_TitleAutoEnabled", setting="MclarionWow_SetAutoTitleCapture",
            description="Auto-capture selected/known titles (off by default)"},
    }
    local function setMessage(index, text)
        if index == 1 then goldMessage = text
        elseif index == 2 then currencyMessage = text
        elseif index == 3 then honorMessage = text
        else titleMessage = text end
        refreshSettingsStatus()
    end
    local function autoState(entry)
        local fn = _G[entry.enabled]
        if type(fn) ~= "function" or isSecret(fn) then return false end
        local ok, value = pcall(fn)
        return ok and value == true
    end
    local heading = companion(settingsWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"))
    heading:SetPoint("TOPLEFT", 18, -48)
    heading:SetText("Wealth, PvP and titles — local observations")
    local scope = companion(settingsWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
    scope:SetPoint("TOPLEFT", 18, -77)
    scope:SetText("Visible currency list is partial; no event or acquisition history implied.")
    local companionChecks = {}
    for index, entry in ipairs(categories) do
        local checkbox = companion(CreateFrame("CheckButton", nil, settingsWindow, "UICheckButtonTemplate"))
        companionChecks[index] = checkbox
        checkbox:SetPoint("TOPLEFT", 18, -112 - (index - 1) * 42)
        local text = companion(settingsWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
        text:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
        text:SetText(entry.description)
        checkbox:SetChecked(autoState(entry))
        checkbox:SetScript("OnClick", function(self)
            local previous = autoState(entry)
            local fn = _G[entry.setting]
            local ok, accepted = false, nil
            if type(fn) == "function" and not isSecret(fn) then
                ok, accepted = pcall(fn, self:GetChecked() == true)
            end
            if not ok or accepted ~= true then
                self:SetChecked(previous)
                setMessage(index, "Setting refused; previous preference preserved.")
            else
                setMessage(index, self:GetChecked() and
                    "Automatic capture enabled; held until WoW saves." or
                    "Automatic capture off; manual capture remains available.")
            end
        end)
    end
    local statusLabels = {}
    for index = 1, 4 do
        local label = companion(settingsWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
        label:SetPoint("TOPLEFT", 18, -314 - (index - 1) * 27)
        statusLabels[index] = label
    end
    goldStatusLabel, currencyStatusLabel, honorStatusLabel, titleStatusLabel =
        statusLabels[1], statusLabels[2], statusLabels[3], statusLabels[4]
    for index, entry in ipairs(categories) do
        local button = companion(CreateFrame("Button", nil, settingsWindow, "UIPanelButtonTemplate"))
        button:SetSize(142, 27)
        button:SetPoint("TOPLEFT", 18 + ((index - 1) % 2) * 158,
            -444 - math.floor((index - 1) / 2) * 38)
        button:SetText(entry.label .. " now")
        button:SetScript("OnClick", function()
            local fn = _G[entry.capture]
            if not inWorld then setMessage(index, "Unavailable before world entry.")
            elseif type(fn) ~= "function" or isSecret(fn) then
                setMessage(index, "Companion addon unavailable; install/enable MclarionWowProgression.")
            else
                local ok, stored, result = pcall(fn, true)
                if not ok or stored ~= true then
                    setMessage(index, "Capture refused; previous observations preserved.")
                elseif result == "saved" then
                    setMessage(index, "Scanned; held in memory until WoW saves.")
                elseif result == "unchanged" then
                    setMessage(index, "Scanned; unchanged.")
                else
                    setMessage(index, "Changed state waits for a later server second.")
                end
            end
        end)
    end
    local reminder = companion(settingsWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
    reminder:SetPoint("TOPLEFT", 18, -548)
    reminder:SetText("Manual scans need no auto opt-in; /reload or exit flushes saves.")
    local legacyTab = CreateFrame("Button", nil, settingsWindow, "UIPanelButtonTemplate")
    legacyTab:SetSize(98, 24)
    legacyTab:SetPoint("TOPRIGHT", -125, -8)
    legacyTab:SetText("Main")
    local companionTab = CreateFrame("Button", nil, settingsWindow, "UIPanelButtonTemplate")
    companionTab:SetSize(108, 24)
    companionTab:SetPoint("TOPRIGHT", -12, -8)
    companionTab:SetText("More captures")
    local function showPage(more)
        for _, widget in ipairs(legacyWidgets) do if more then widget:Hide() else widget:Show() end end
        for _, widget in ipairs(companionWidgets) do if more then widget:Show() else widget:Hide() end end
        if more then
            for index, entry in ipairs(categories) do companionChecks[index]:SetChecked(autoState(entry)) end
        end
        refreshSettingsStatus()
    end
    legacyTab:SetScript("OnClick", function() showPage(false) end)
    companionTab:SetScript("OnClick", function() showPage(true) end)
    showPage(false)
    settingsWindow:Hide()
end

SLASH_MCLARIONWOWUI1 = "/mhwowui"
SlashCmdList.MCLARIONWOWUI = function()
    if not settingsWindow then createSettingsWindow() end
    refreshSettingsStatus()
    settingsWindow:Show()
end

-- Keep the settings reachable without typing a command. The minimap may not
-- exist in stripped-down clients, in which case /mhwowui remains available.
if not isSecret(Minimap) and type(Minimap) == "table" and not issecrettable(Minimap) then
    local button = CreateFrame("Button", "MclarionWowMinimapButton", Minimap)
    button:SetSize(30, 30)
    button:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", -8, -8)
    button:SetFrameStrata("MEDIUM")
    button:SetNormalTexture("Interface\\Icons\\INV_Misc_Map_01")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetScript("OnClick", function()
        if settingsWindow and settingsWindow:IsShown() then
            settingsWindow:Hide()
        else
            SlashCmdList.MCLARIONWOWUI()
        end
    end)
end

SLASH_MCLARIONWOWBAGS1 = "/mhwowbags"
SlashCmdList.MCLARIONWOWBAGS = function()
    local ok, report, err = pcall(MclarionWow_ProbeBags)
    print("MclarionWow: " .. (ok and (report or err) or "Bag probe unavailable."))
end

SLASH_MCLARIONWOWBANKPROBE1 = "/mhwowbankprobe"
SlashCmdList.MCLARIONWOWBANKPROBE = function()
    local ok, report, err = pcall(MclarionWow_ProbeBank)
    print("MclarionWow: " .. (ok and (report or err) or "Bank probe unavailable."))
end

SLASH_MCLARIONWOWPROGRESSPROBE1 = "/mhwowprogressprobe"
SlashCmdList.MCLARIONWOWPROGRESSPROBE = function()
    local ok, report, err = pcall(MclarionWow_ProbeProgression)
    print("MclarionWow: " .. (ok and (report or err) or "Progression probe unavailable."))
end

SLASH_MCLARIONWOWPROGRESSRECORDS1 = "/mhwowprogressrecords"
SlashCmdList.MCLARIONWOWPROGRESSRECORDS = function()
    local ok, report, err = pcall(MclarionWow_ProbeProgressionRecords)
    print("MclarionWow: " .. (ok and (report or err) or "Progression record probe unavailable."))
end

SLASH_MCLARIONWOWPROGRESSNAMESPACED1 = "/mhwowprogressnamespaced"
SlashCmdList.MCLARIONWOWPROGRESSNAMESPACED = function()
    local ok, report, err = pcall(MclarionWow_ProbeProgressionNamespaced)
    print("MclarionWow: " .. (ok and (report or err) or "Namespaced progression probe unavailable."))
end

SLASH_MCLARIONWOWPROGRESSSAFETY1 = "/mhwowprogresssafety"
SlashCmdList.MCLARIONWOWPROGRESSSAFETY = function()
    local ok, report, err = pcall(MclarionWow_ProbeProgressionSafety)
    print("MclarionWow: " .. (ok and (report or err) or "Progression safety probe unavailable."))
end

SLASH_MCLARIONWOWSIZEPROBE1 = "/mhwowsizeprobe"
SlashCmdList.MCLARIONWOWSIZEPROBE = function()
    local ok, report, err = pcall(MclarionWow_ProbeSavedSize)
    print("MclarionWow: " .. (ok and (report or err) or "Size probe unavailable."))
end

SLASH_MCLARIONWOWMIGRATIONPREFLIGHT1 = "/mhwowmigrationpreflight"
SlashCmdList.MCLARIONWOWMIGRATIONPREFLIGHT = function()
    local ok, report, err = pcall(MclarionWow_ProbeSchema3Preflight)
    print("MclarionWow: " .. (ok and (report or err) or "Migration preflight unavailable."))
end

local captureFrame = CreateFrame("Frame")
local elapsed = 0
local function captureQuestsAutomatically()
    if not inWorld or type(MclarionWow_QuestAutoEnabled) ~= "function" or
        not MclarionWow_QuestAutoEnabled() then return end
    local ok, captured, result = pcall(MclarionWow_CaptureQuests, false)
    if not ok or captured ~= true then
        questMessage = "Automatic scan refused; prior observations preserved."
    elseif result == "saved" then questMessage = "Scanned; held in memory until WoW saves."
    elseif result == "unchanged" then questMessage = "Scanned; unchanged."
    else questMessage = "Changed state waits for a later server second." end
    refreshSettingsStatus()
end
local function captureReputationAutomatically()
    if not inWorld or type(MclarionWow_ReputationAutoEnabled) ~= "function" or
        not MclarionWow_ReputationAutoEnabled() or
        type(MclarionWow_CaptureReputation) ~= "function" then return end
    local ok, captured, result = pcall(MclarionWow_CaptureReputation, false)
    if not ok or captured ~= true then
        reputationMessage = "Automatic scan refused; prior observations preserved."
    elseif result == "saved" then reputationMessage = "Scanned; held in memory until WoW saves."
    elseif result == "unchanged" then reputationMessage = "Scanned; unchanged."
    else reputationMessage = "Changed state waits for a later server second." end
    refreshSettingsStatus()
end
local function captureCompanionsAutomatically()
    if not inWorld then return end
    local categories = {
        {MclarionWow_GoldAutoEnabled, MclarionWow_CaptureGold},
        {MclarionWow_CurrencyAutoEnabled, MclarionWow_CaptureCurrency},
        {MclarionWow_HonorAutoEnabled, MclarionWow_CaptureHonor},
        {MclarionWow_TitleAutoEnabled, MclarionWow_CaptureTitle},
    }
    for index, category in ipairs(categories) do
        local enabled, capture = category[1], category[2]
        if not isSecret(enabled) and type(enabled) == "function" and
            not isSecret(capture) and type(capture) == "function" then
            local checked, active = pcall(enabled)
            if checked and active == true then
                local ok, stored, status = pcall(capture, false)
                local message
                if not ok or stored ~= true then
                    message = "Automatic scan refused; previous observations preserved."
                elseif status == "saved" then
                    message = "Scanned; held in memory until WoW saves."
                elseif status == "unchanged" then
                    message = "Scanned; unchanged."
                else
                    message = "Changed state waits for a later server second."
                end
                if index == 1 then goldMessage = message
                elseif index == 2 then currencyMessage = message
                elseif index == 3 then honorMessage = message
                else titleMessage = message end
            end
        end
    end
    refreshSettingsStatus()
end
local function enableCombatLogging()
    local settings, err = settingsRoot()
    if not settings then
        combatMessage = "Unavailable (" .. (err or "settings error") .. ")"
    elseif not settings.autoCombatLog then
        combatMessage = "Automatic start disabled in settings."
    elseif isSecret(LoggingCombat) then
        combatMessage = "Unavailable: client protects the logging API."
    elseif type(LoggingCombat) ~= "function" then
        combatMessage = "Unavailable: client does not expose combat logging."
    else
        local ok, active = pcall(LoggingCombat)
        if not ok or isSecret(active) or type(active) ~= "boolean" then
            combatMessage = "Unavailable: client refused logging status."
        elseif active then
            combatMessage = "On; WoW owns the combat-log file."
        else
            local started = pcall(LoggingCombat, true)
            local checked, enabled = pcall(LoggingCombat)
            if started and checked and not isSecret(enabled) and enabled == true then
                combatMessage = "On; WoW owns the combat-log file."
            else
                combatMessage = "Unavailable: client refused to enable logging."
            end
        end
    end
    refreshSettingsStatus()
end
local function captureLocally()
    if not inWorld then return end
    local settings = settingsRoot()
    if not settings or not settings.autoCharacterCapture then return end
    local combat = combatStatus()
    if combat == nil or combat then return end
    local ok, export, _, guid = pcall(MclarionWow_BuildIdentityExport)
    if not ok or not export then
        -- Unavailable identity APIs must not suppress the existing gear capture.
        ok, export, _, guid = pcall(MclarionWow_BuildExport)
    end
    if ok and export and guid then
        local saved, stored = pcall(saveSnapshot, guid, export)
        characterMessage = saved and stored and
            "Scanned; unchanged or held in memory until WoW saves." or
            "Capture unavailable: local storage was refused."
    else
        characterMessage = "Capture unavailable: client refused character scan."
    end
    refreshSettingsStatus()
end

local function captureBagsLocally(explicit)
    if not inWorld then return end
    local settings = settingsRoot()
    if not settings then
        bagMessage = "Capture unavailable: addon settings were refused."
        refreshSettingsStatus()
        return
    end
    if not settings.autoBagCapture then return end
    local combat = combatStatus()
    if combat == nil or combat then return end
    local ok, export, _, guid = pcall(MclarionWow_BuildBagExport)
    if ok and export and guid then
        local saved, stored, storageError = pcall(saveBagSnapshot, guid, export, explicit == true)
        if saved and stored then
            bagMessage = "Scanned; unchanged or held in memory until WoW saves."
        else
            bagMessage = storageError == "Empty bag scan needs explicit confirmation." and
                "Empty result refused; check bags, then click Bags now if truly empty." or
                "Capture unavailable: local bag storage was refused."
        end
    else
        bagMessage = "Capture unavailable: client refused the bag scan."
    end
    refreshSettingsStatus()
end

local function captureBankLocally(explicit)
    if not inWorld then return end
    local settings = settingsRoot()
    if not settings then
        bankMessage = "Capture unavailable: addon settings were refused."
        refreshSettingsStatus()
        return
    end
    if not settings.autoBankCapture then return end
    local combat = combatStatus()
    if combat == nil or combat then return end
    -- The shared scanner rejects hidden/account-bank views and protected APIs
    -- before any slot is read for automatic capture.
    local ok, export, scanError, guid = pcall(MclarionWow_BuildBankExport)
    if ok and export and guid then
        local saved, stored, storageError = pcall(saveBankSnapshot, guid, export, explicit == true)
        if saved and stored then
            bankMessage = "Scanned; unchanged or held in memory until WoW saves."
        else
            bankMessage = storageError == "Empty bank scan needs explicit confirmation." and
                "Empty result refused; check bank, then click Bank now if truly empty." or
                "Capture unavailable: local bank storage was refused."
        end
    else
        bankMessage = scanError == "Character bank view is not active." and
            "Select your character-bank tab; no scan performed." or
            "Capture unavailable: client refused the bank scan."
    end
    refreshSettingsStatus()
end

local function captureItemDetailsLocally(source)
    if not inWorld then return end
    local settings = settingsRoot()
    if not settings or not settings.autoItemMetadataCapture then return end
    local combat = combatStatus()
    if combat == nil or combat then return end
    local ok, export, scanError, guid, _, pageCount, resolved, observed
    local payload
    if source == "bank" then
        ok, export, scanError, guid, _, pageCount, resolved, observed =
            pcall(MclarionWow_BuildBankItemExport, 1)
        if ok and export and not isSecret(pageCount) and type(pageCount) == "number" and
            pageCount >= 1 and pageCount <= 9 and pageCount == math.floor(pageCount) and
            not isSecret(resolved) and not isSecret(observed) and resolved == observed then
            payload = { export }
            for page = 2, pageCount do
                local pageOk, text, _, pageGuid, actualPage, totalPages, cached, seen =
                    pcall(MclarionWow_BuildBankItemExport, page)
                if not pageOk or not text or pageGuid ~= guid or actualPage ~= page or
                    totalPages ~= pageCount or isSecret(cached) or isSecret(seen) or
                    cached ~= seen then payload = nil; break end
                payload[page] = text
            end
        end
    else
        ok, export, scanError, guid, resolved, observed = pcall(MclarionWow_BuildItemExport)
        if ok and export and not isSecret(resolved) and not isSecret(observed) and
            resolved == observed then payload = export end
    end
    if payload and guid then
        local saved, stored, storageError = pcall(saveItemMetadata, guid, source, payload)
        itemMessage = saved and stored and
            "Scanned; unchanged or held in memory until WoW saves." or
            "Capture unavailable: " .. (saved and (storageError or "local storage refused") or
                "client refused local storage") .. "."
    else
        itemMessage = source == "bank" and scanError == "Character bank view is not active." and
            "Select your character-bank tab; no scan performed." or
            (scanError == "Item names are not available from the client cache." or
            (ok and export and not isSecret(resolved) and not isSecret(observed) and
                type(resolved) == "number" and type(observed) == "number" and
                resolved ~= observed)) and
            "Cache incomplete; no replacement saved. Reopen bags later." or
            "Capture unavailable: client refused a complete item scan."
    end
    refreshSettingsStatus()
end

captureNow = function(kind)
    local settings = settingsRoot()
    local flags = { character = "autoCharacterCapture", bags = "autoBagCapture",
        bank = "autoBankCapture", items = "autoItemMetadataCapture" }
    local flag = flags[kind]
    if not flag then return end
    local enabled = settings and (kind == "bank" and
        (settings.autoBankCapture or settings.autoItemMetadataCapture) or settings[flag])
    if not enabled then
        local message = settings and "Enable the matching checkbox first." or
            "Capture unavailable: addon settings were refused."
        if kind == "character" then characterMessage = message
        elseif kind == "bags" then bagMessage = message
        elseif kind == "bank" then bankMessage = message
        else itemMessage = message end
        refreshSettingsStatus()
        return
    end
    local combat = combatStatus()
    if not inWorld or combat ~= false then
        local message = "Capture unavailable in combat or before world entry."
        if kind == "character" then characterMessage = message
        elseif kind == "bags" then bagMessage = message
        elseif kind == "bank" then bankMessage = message
        else itemMessage = message end
        refreshSettingsStatus()
        return
    end
    if kind == "character" then captureLocally()
    elseif kind == "bags" then captureBagsLocally(true)
    elseif kind == "bank" then
        if settings.autoBankCapture then captureBankLocally(true)
        else
            bankMessage = "Bank totals off; item details only."
            refreshSettingsStatus()
        end
        if settings.autoItemMetadataCapture then captureItemDetailsLocally("bank") end
    else captureItemDetailsLocally("bags") end
end

for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_LEVEL_UP", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED", "BAG_OPEN",
    "BANKFRAME_OPENED", "PLAYERBANKSLOTS_CHANGED", "BANK_TABS_CHANGED",
    "QUEST_LOG_UPDATE", "UPDATE_FACTION" }) do
    captureFrame:RegisterEvent(event)
end
local function onEvent(_, event, bagID)
    if event == "PLAYER_ENTERING_WORLD" then
        inWorld = true
        enableCombatLogging()
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "QUEST_LOG_UPDATE" or
        event == "PLAYER_REGEN_ENABLED" then pcall(captureQuestsAutomatically) end
    if event == "PLAYER_ENTERING_WORLD" or event == "UPDATE_FACTION" or
        event == "PLAYER_REGEN_ENABLED" then pcall(captureReputationAutomatically) end
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
        pcall(captureCompanionsAutomatically)
    end
    if event ~= "QUEST_LOG_UPDATE" and event ~= "UPDATE_FACTION" and
        event ~= "BAG_UPDATE_DELAYED" and event ~= "BAG_OPEN" and
        event ~= "BANKFRAME_OPENED" and event ~= "PLAYERBANKSLOTS_CHANGED" and
        event ~= "BANK_TABS_CHANGED" then pcall(captureLocally) end
    if event == "PLAYER_ENTERING_WORLD" or event == "BAG_UPDATE_DELAYED" or
        event == "PLAYER_REGEN_ENABLED" or (event == "BAG_OPEN" and
        not isSecret(bagID) and type(bagID) == "number" and
        bagID == math.floor(bagID) and bagID >= 0 and bagID <= 4) then
        pcall(captureBagsLocally)
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_EQUIPMENT_CHANGED" or
        event == "PLAYER_REGEN_ENABLED" or event == "BAG_UPDATE_DELAYED" or
        (event == "BAG_OPEN" and not isSecret(bagID) and type(bagID) == "number" and
            bagID == math.floor(bagID) and bagID >= 0 and bagID <= 4) then
        pcall(captureItemDetailsLocally, "bags")
    end
    if event == "BANKFRAME_OPENED" or event == "PLAYERBANKSLOTS_CHANGED" or
        event == "BANK_TABS_CHANGED" then
        pcall(captureBankLocally)
        pcall(captureItemDetailsLocally, "bank")
    end
end
captureFrame:SetScript("OnEvent", function(...) pcall(onEvent, ...) end)
if not isSecret(EventRegistry) and type(EventRegistry) == "table" and
    not issecrettable(EventRegistry) and
    not isSecret(EventRegistry.RegisterCallback) and
    type(EventRegistry.RegisterCallback) == "function" then
    pcall(EventRegistry.RegisterCallback, EventRegistry,
        "BankPanelMixin.PageSelected", function()
            pcall(captureBankLocally)
            pcall(captureItemDetailsLocally, "bank")
        end, captureFrame)
end
local function onUpdate(_, delta)
    elapsed = elapsed + delta
    if elapsed >= 300 then
        elapsed = 0
        pcall(captureLocally)
        pcall(captureBagsLocally)
        pcall(captureItemDetailsLocally, "bags")
        pcall(captureQuestsAutomatically)
        pcall(captureReputationAutomatically)
        pcall(captureCompanionsAutomatically)
    end
end
captureFrame:SetScript("OnUpdate", function(...) pcall(onUpdate, ...) end)
