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
    return type(value) == "number" and value > 0 and value == math.floor(value)
end

local function nonnegativeInteger(value)
    return type(value) == "number" and value >= 0 and value == math.floor(value)
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
    if type(zoneText) ~= "string" or #zoneText > 120 then
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

-- Shared, fail-closed scanner for the diagnostic and manual bag export.
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

-- Manual count-only diagnostic for purchased tabs in the character's own viewable bank.
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

-- Manual-only export of item totals from purchased tabs in the character's own
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

-- A separate, manually reviewed catalogue for the player's own observed IDs.
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
    return export, nil, guid
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
    local export, exportError, guid = buildItemMetadataExport(pageIds, getInfo)
    if not export then return nil, exportError end
    return export, nil, guid, page, pageCount
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
    if schema ~= 1 then
        return nil, "Saved data has an unsupported format; it was not overwritten."
    end
    local characters = data.characters
    if isSecret(characters) or (type(characters) == "table" and issecrettable(characters)) then
        return nil, "Saved character data is protected by the client; it was not overwritten."
    end
    if type(characters) ~= "table" then
        return nil, "Saved data has an unsupported format; it was not overwritten."
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
        isSecret(settings.autoBankCapture) or
        type(settings.autoCombatLog) ~= "boolean" or
        type(settings.autoBagCapture) ~= "boolean" or
        (settings.autoCharacterCapture ~= nil and type(settings.autoCharacterCapture) ~= "boolean") or
        (settings.autoBankCapture ~= nil and type(settings.autoBankCapture) ~= "boolean") then
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
    local details = export:match("^MHWOW1|forever|%d+|(.*)$")
    local last = snapshots[count]
    local previous = last and last:match("^MHWOW1|forever|%d+|(.*)$")
    if last ~= export and (details == nil or details ~= previous) then
        snapshots[#snapshots + 1] = export
        if #snapshots > 20 then
            table.remove(snapshots, 1)
        end
    end
    return true
end

local function saveBagSnapshot(guid, export)
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
    if details ~= previous then
        snapshots[#snapshots + 1] = export
        if #snapshots > 20 then table.remove(snapshots, 1) end
    end
    return true
end

local function saveBankSnapshot(guid, export)
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
    if details ~= previous then
        snapshots[#snapshots + 1] = export
        if #snapshots > 20 then table.remove(snapshots, 1) end
    end
    return true
end

local window
local exportBox, windowTitle, windowInstructions
local displayedExport
local settingsWindow, combatStatusLabel, bagStatusLabel, bankStatusLabel, exportStatusLabel
local combatMessage = "Waiting for the next login."
local bagMessage = "No bag capture this session."
local bankMessage = "No own-bank capture this session."
local exportMessage = "No copy window opened this session."

local function refreshSettingsStatus()
    if combatStatusLabel then combatStatusLabel:SetText("Combat log: " .. combatMessage) end
    if bagStatusLabel then bagStatusLabel:SetText("Bags: " .. bagMessage) end
    if bankStatusLabel then bankStatusLabel:SetText("Bank: " .. bankMessage) end
    if exportStatusLabel then exportStatusLabel:SetText("Export: " .. exportMessage) end
end

local function recordExport(label, saved)
    exportMessage = label .. (saved and
        " snapshot stored in memory; WoW saves it later. No separate TXT file." or
        " copy window opened; no separate TXT file was written.")
    refreshSettingsStatus()
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
    settingsWindow:SetSize(490, 430)
    settingsWindow:SetPoint("CENTER")
    settingsWindow:SetFrameStrata("DIALOG")
    settingsWindow:SetMovable(true)
    settingsWindow:EnableMouse(true)
    settingsWindow:RegisterForDrag("LeftButton")
    settingsWindow:SetScript("OnDragStart", settingsWindow.StartMoving)
    settingsWindow:SetScript("OnDragStop", settingsWindow.StopMovingOrSizing)

    local title = settingsWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -10)
    title:SetText("Vaultkeeper companion")
    local note = settingsWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    note:SetPoint("TOPLEFT", 18, -42)
    note:SetText("Snapshots remain in memory until WoW saves them on logout or /reload.")

    local function checkbox(label, y, key)
        local button = CreateFrame("CheckButton", nil, settingsWindow, "UICheckButtonTemplate")
        button:SetPoint("TOPLEFT", 18, y)
        local text = settingsWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", button, "RIGHT", 4, 0)
        text:SetText(label)
        local settings = settingsRoot()
        button:SetChecked(settings and settings[key] or false)
        button:SetScript("OnClick", function(self)
            local current = settingsRoot()
            if not current then self:SetChecked(false); return end
            current[key] = self:GetChecked() == true
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
    local combatCheckbox = checkbox("Enable WoW combat logging at login", -67, "autoCombatLog")
    checkbox("Capture own character state, out of combat", -98, "autoCharacterCapture")
    checkbox("Capture own bag changes, out of combat", -129, "autoBagCapture")
    checkbox("Capture own bank while open, out of combat", -160, "autoBankCapture")

    combatStatusLabel = settingsWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    combatStatusLabel:SetPoint("TOPLEFT", 18, -200)
    bagStatusLabel = settingsWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bagStatusLabel:SetPoint("TOPLEFT", 18, -222)
    bankStatusLabel = settingsWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bankStatusLabel:SetPoint("TOPLEFT", 18, -244)
    exportStatusLabel = settingsWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    exportStatusLabel:SetPoint("TOPLEFT", 18, -266)
    refreshSettingsStatus()

    local function exportButton(label, x, callback)
        local button = CreateFrame("Button", nil, settingsWindow, "UIPanelButtonTemplate")
        button:SetSize(140, 25)
        button:SetPoint("TOPLEFT", x, -297)
        button:SetText(label)
        button:SetScript("OnClick", callback)
    end
    exportButton("Character", 18, function() SlashCmdList.MCLARIONWOW() end)
    exportButton("Bags", 170, function() SlashCmdList.MCLARIONWOWBAGSEXPORT() end)
    exportButton("Bank (manual)", 322, function() SlashCmdList.MCLARIONWOWBANKSEXPORT() end)
    local stopButton = CreateFrame("Button", nil, settingsWindow, "UIPanelButtonTemplate")
    stopButton:SetSize(175, 25)
    stopButton:SetPoint("TOPLEFT", 18, -329)
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
    local footer = settingsWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    footer:SetPoint("TOPLEFT", 18, -367)
    footer:SetText("Stop logging now may end logging started outside this addon.")
    local saveNote = settingsWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    saveNote:SetPoint("TOPLEFT", 18, -389)
    saveNote:SetText("Bank names need manual export. WoW controls disk writes.")
    settingsWindow:Hide()
end

local function setExportText(text)
    displayedExport = text
    exportBox:SetText(text)
end

local function createWindow()
    window = CreateFrame("Frame", "MclarionWowExportFrame", UIParent, "BasicFrameTemplateWithInset")
    window:SetSize(760, 210)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)

    windowTitle = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    windowTitle:SetPoint("TOPLEFT", 12, -8)
    windowTitle:SetText("MclarionWow — manual snapshot export")

    windowInstructions = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    windowInstructions:SetPoint("TOPLEFT", 16, -38)
    windowInstructions:SetText("The text below is selected. Press Ctrl+C, then paste it where you choose.")

    exportBox = CreateFrame("EditBox", "MclarionWowExportEditBox", window, "InputBoxTemplate")
    exportBox:SetPoint("TOPLEFT", 18, -68)
    exportBox:SetPoint("BOTTOMRIGHT", -18, 22)
    exportBox:SetAutoFocus(false)
    exportBox:SetMultiLine(true)
    exportBox:SetFontObject(ChatFontNormal)
    exportBox:SetTextInsets(8, 8, 8, 8)
    exportBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput and displayedExport then
            -- Typing with the export selected would replace part of a valid payload.
            self:SetText(displayedExport)
            self:HighlightText()
        end
    end)
    exportBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        window:Hide()
    end)

    window:Hide()
end

local function setWindowMode(bankDiagnostic)
    if not window then createWindow() end
    windowTitle:SetText(bankDiagnostic and "MclarionWow — Bank diagnostic (counts only)" or
        "MclarionWow — manual snapshot export")
    windowInstructions:SetText(bankDiagnostic and
        "Only aggregate counts are shown. Press Ctrl+C to copy; no bank items are saved." or
        "The text below is selected. Press Ctrl+C, then paste it where you choose.")
end

local function showExport()
    setWindowMode(false)

    local ok, export, err, guid = pcall(MclarionWow_BuildExport)
    if ok and export then
        local savedOk, stored, storageError = pcall(saveSnapshot, guid, export)
        if savedOk and stored then recordExport("Character", true) end
        setExportText(savedOk and stored and export or "Storage unavailable: " ..
            (savedOk and (storageError or "unknown error") or "client refused to save."))
    else
        setExportText("Export unavailable: " ..
            (ok and (err or "unknown error") or "client refused the scan."))
    end
    window:Show()
    exportBox:Show()
    exportBox:SetFocus()
    exportBox:HighlightText()
end

SLASH_MCLARIONWOW1 = "/mhwow"
SlashCmdList.MCLARIONWOW = showExport

SLASH_MCLARIONWOWUI1 = "/mhwowui"
SlashCmdList.MCLARIONWOWUI = function()
    if not settingsWindow then createSettingsWindow() end
    refreshSettingsStatus()
    settingsWindow:Show()
end

local function showBagExport()
    setWindowMode(false)
    local ok, export, err, guid = pcall(MclarionWow_BuildBagExport)
    if ok and export then
        local savedOk, stored, storageError = pcall(saveBagSnapshot, guid, export)
        if savedOk and stored then
            recordExport("Bags", true)
            setExportText(export)
        else
            setExportText("Storage unavailable: " ..
                (savedOk and (storageError or "unknown error") or "client refused to save."))
        end
    else
        setExportText("Bag export unavailable: " ..
            (ok and (err or "unknown error") or "client refused the scan."))
    end
    window:Show()
    exportBox:Show()
    exportBox:SetFocus()
    exportBox:HighlightText()
end

SLASH_MCLARIONWOWBAGSEXPORT1 = "/mhwowbagsexport"
SlashCmdList.MCLARIONWOWBAGSEXPORT = showBagExport

SLASH_MCLARIONWOWITEMSEXPORT1 = "/mhwowitemsexport"
SlashCmdList.MCLARIONWOWITEMSEXPORT = function()
    setWindowMode(false)
    local ok, export, err = pcall(MclarionWow_BuildItemExport)
    if ok and export then recordExport("Bag and gear details") end
    setExportText(ok and (export or "Item export unavailable: " .. (err or "unknown error")) or
        "Item export unavailable: client refused the scan.")
    window:Show()
    exportBox:Show()
    exportBox:SetFocus()
    exportBox:HighlightText()
end

SLASH_MCLARIONWOWBAGS1 = "/mhwowbags"
SlashCmdList.MCLARIONWOWBAGS = function()
    local ok, report, err = pcall(MclarionWow_ProbeBags)
    print("MclarionWow: " .. (ok and (report or err) or "Bag probe unavailable."))
end

SLASH_MCLARIONWOWBANKPROBE1 = "/mhwowbankprobe"
SlashCmdList.MCLARIONWOWBANKPROBE = function()
    local ok, report, err = pcall(MclarionWow_ProbeBank)
    setWindowMode(true)
    setExportText(ok and (report or "Bank probe unavailable: " .. (err or "unknown error")) or
        "Bank probe unavailable: client refused the scan.")
    window:Show()
    exportBox:Show()
    exportBox:SetFocus()
    exportBox:HighlightText()
end

SLASH_MCLARIONWOWBANKSEXPORT1 = "/mhwowbanksexport"
SlashCmdList.MCLARIONWOWBANKSEXPORT = function()
    local ok, export, err = pcall(MclarionWow_BuildBankExport)
    if ok and export then recordExport("Bank (manual)") end
    if not window then createWindow() end
    windowTitle:SetText("MclarionWow — Bank item export (manual only)")
    windowInstructions:SetText(
        "Review before copying. No bank item data is saved; press Ctrl+C to copy where you choose.")
    setExportText(ok and (export or "Bank export unavailable: " .. (err or "unknown error")) or
        "Bank export unavailable: client refused the scan.")
    window:Show()
    exportBox:Show()
    exportBox:SetFocus()
    exportBox:HighlightText()
end

local function parseBankItemPage(message)
    if isSecret(message) then return nil, "Bank metadata page is protected by the client." end
    if message == nil or message == "" or (type(message) == "string" and message:match("^%s*$")) then
        return 1
    end
    if type(message) ~= "string" then return nil, "Bank metadata page is invalid." end
    local digits = message:match("^%s*(%d+)%s*$")
    local page = digits and tonumber(digits) or nil
    if not positiveInteger(page) or page > 9 then
        return nil, "Bank metadata page must be an integer from 1 to 9."
    end
    return page
end

SLASH_MCLARIONWOWBANKITEMSEXPORT1 = "/mhwowbankitemsexport"
SlashCmdList.MCLARIONWOWBANKITEMSEXPORT = function(message)
    if not window then createWindow() end
    windowTitle:SetText("MclarionWow — Bank item metadata (manual only)")
    windowInstructions:SetText(
        "Review MHWOWI1 before copying. Use /mhwowbankitemsexport 2 for the next page when shown.")
    local page, pageError = parseBankItemPage(message)
    if not page then
        setExportText("Bank item metadata export unavailable: " .. pageError)
    else
        local ok, export, err, _, selectedPage, pageCount = pcall(MclarionWow_BuildBankItemExport, page)
        if ok and export then
            recordExport("Bank details (manual)")
            windowTitle:SetText(string.format(
                "MclarionWow — Bank item metadata (manual only, page %d/%d)", selectedPage, pageCount))
            setExportText(export)
        else
            setExportText("Bank item metadata export unavailable: " ..
                (ok and (err or "unknown error") or "client refused the scan."))
        end
    end
    window:Show()
    exportBox:Show()
    exportBox:SetFocus()
    exportBox:HighlightText()
end

local captureFrame = CreateFrame("Frame")
local inWorld = false
local elapsed = 0
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
    local ok, export, _, guid = pcall(MclarionWow_BuildExport)
    if ok and export and guid then
        pcall(saveSnapshot, guid, export)
    end
end

local function captureBagsLocally()
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
        local saved, stored = pcall(saveBagSnapshot, guid, export)
        if saved and stored then
            bagMessage = "Captured in memory; disk update waits for logout or /reload."
        else
            bagMessage = "Capture unavailable: local bag storage was refused."
        end
    else
        bagMessage = "Capture unavailable: client refused the bag scan."
    end
    refreshSettingsStatus()
end

local function captureBankLocally()
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
    -- before any slot is read, for automatic and manual paths alike.
    local ok, export, _, guid = pcall(MclarionWow_BuildBankExport)
    if ok and export and guid then
        local saved, stored = pcall(saveBankSnapshot, guid, export)
        if saved and stored then
            bankMessage = "Captured in memory; disk update waits for logout or /reload."
        else
            bankMessage = "Capture unavailable: local bank storage was refused."
        end
    else
        bankMessage = "Capture unavailable: client refused the bank scan."
    end
    refreshSettingsStatus()
end

for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED", "BAG_OPEN",
    "BANKFRAME_OPENED", "PLAYERBANKSLOTS_CHANGED", "BANK_TABS_CHANGED" }) do
    captureFrame:RegisterEvent(event)
end
local function onEvent(_, event, bagID)
    if event == "PLAYER_ENTERING_WORLD" then
        inWorld = true
        enableCombatLogging()
    end
    if event ~= "BAG_UPDATE_DELAYED" and event ~= "BAG_OPEN" and
        event ~= "BANKFRAME_OPENED" and event ~= "PLAYERBANKSLOTS_CHANGED" and
        event ~= "BANK_TABS_CHANGED" then pcall(captureLocally) end
    if event == "PLAYER_ENTERING_WORLD" or event == "BAG_UPDATE_DELAYED" or
        event == "PLAYER_REGEN_ENABLED" or (event == "BAG_OPEN" and
        not isSecret(bagID) and type(bagID) == "number" and
        bagID == math.floor(bagID) and bagID >= 0 and bagID <= 4) then
        pcall(captureBagsLocally)
    end
    if event == "BANKFRAME_OPENED" or event == "PLAYERBANKSLOTS_CHANGED" or
        event == "BANK_TABS_CHANGED" then pcall(captureBankLocally) end
end
captureFrame:SetScript("OnEvent", function(...) pcall(onEvent, ...) end)
if not isSecret(EventRegistry) and type(EventRegistry) == "table" and
    not issecrettable(EventRegistry) and
    not isSecret(EventRegistry.RegisterCallback) and
    type(EventRegistry.RegisterCallback) == "function" then
    pcall(EventRegistry.RegisterCallback, EventRegistry,
        "BankPanelMixin.PageSelected", function() pcall(captureBankLocally) end, captureFrame)
end
local function onUpdate(_, delta)
    elapsed = elapsed + delta
    if elapsed >= 300 then
        elapsed = 0
        pcall(captureLocally)
        pcall(captureBagsLocally)
    end
end
captureFrame:SetScript("OnUpdate", function(...) pcall(onUpdate, ...) end)
