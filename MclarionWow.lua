local ADDON_NAME = ...

local function isSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function combatStatus()
    if type(issecretvalue) ~= "function" or type(issecrettable) ~= "function" then
        return nil, "Protection checks are unavailable."
    end
    local value = InCombatLockdown()
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

function MclarionWow_BuildExport()
    local combat, combatError = combatStatus()
    if combat == nil then return nil, combatError end
    if combat then
        return nil, "MclarionWow will not export while you are in combat."
    end

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

function MclarionWow_BuildBagExport()
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

function MclarionWow_BuildItemExport()
    local report, totalsOrError = scanBags(true)
    if not report then return nil, totalsOrError end
    if isSecret(C_Item) or type(C_Item) ~= "table" or issecrettable(C_Item) then
        return nil, "Item API is unavailable."
    end
    local getInfo = C_Item.GetItemInfo
    if isSecret(getInfo) or isSecret(GetInventoryItemID) or isSecret(GetLocale) or
        isSecret(GetServerTime) or isSecret(UnitGUID) or isSecret(GetBuildInfo) then
        return nil, "Item export API is protected by the client."
    end
    if type(getInfo) ~= "function" or
        type(GetInventoryItemID) ~= "function" or type(GetLocale) ~= "function" then
        return nil, "Item API is unavailable."
    end
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

local window
local exportBox

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

    local title = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", 12, -8)
    title:SetText("MclarionWow — manual snapshot export")

    local instructions = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructions:SetPoint("TOPLEFT", 16, -38)
    instructions:SetText("The text below is selected. Press Ctrl+C, then paste it where you choose.")

    exportBox = CreateFrame("EditBox", "MclarionWowExportEditBox", window, "InputBoxTemplate")
    exportBox:SetPoint("TOPLEFT", 18, -68)
    exportBox:SetPoint("BOTTOMRIGHT", -18, 22)
    exportBox:SetAutoFocus(false)
    exportBox:SetMultiLine(true)
    exportBox:SetFontObject(ChatFontNormal)
    exportBox:SetTextInsets(8, 8, 8, 8)
    exportBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        window:Hide()
    end)

    window:Hide()
end

local function showExport()
    if not window then
        createWindow()
    end

    local ok, export, err, guid = pcall(MclarionWow_BuildExport)
    if ok and export then
        local savedOk, stored, storageError = pcall(saveSnapshot, guid, export)
        exportBox:SetText(savedOk and stored and export or "Storage unavailable: " ..
            (savedOk and (storageError or "unknown error") or "client refused to save."))
    else
        exportBox:SetText("Export unavailable: " ..
            (ok and (err or "unknown error") or "client refused the scan."))
    end
    window:Show()
    exportBox:Show()
    exportBox:SetFocus()
    exportBox:HighlightText()
end

SLASH_MCLARIONWOW1 = "/mhwow"
SlashCmdList.MCLARIONWOW = showExport

local function showBagExport()
    if not window then createWindow() end
    local ok, export, err, guid = pcall(MclarionWow_BuildBagExport)
    if ok and export then
        local savedOk, stored, storageError = pcall(saveBagSnapshot, guid, export)
        if savedOk and stored then
            exportBox:SetText(export)
        else
            exportBox:SetText("Storage unavailable: " ..
                (savedOk and (storageError or "unknown error") or "client refused to save."))
        end
    else
        exportBox:SetText("Bag export unavailable: " ..
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
    if not window then createWindow() end
    local ok, export, err = pcall(MclarionWow_BuildItemExport)
    exportBox:SetText(ok and (export or "Item export unavailable: " .. (err or "unknown error")) or
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

local captureFrame = CreateFrame("Frame")
local inWorld = false
local elapsed = 0
local function captureLocally()
    if not inWorld then return end
    local combat = combatStatus()
    if combat == nil or combat then return end
    local ok, export, _, guid = pcall(MclarionWow_BuildExport)
    if ok and export and guid then
        pcall(saveSnapshot, guid, export)
    end
end

local function captureBagsLocally()
    if not inWorld then return end
    local combat = combatStatus()
    if combat == nil or combat then return end
    local ok, export, _, guid = pcall(MclarionWow_BuildBagExport)
    if ok and export and guid then pcall(saveBagSnapshot, guid, export) end
end

for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED" }) do
    captureFrame:RegisterEvent(event)
end
local function onEvent(_, event)
    if event == "PLAYER_ENTERING_WORLD" then inWorld = true end
    if event ~= "BAG_UPDATE_DELAYED" then pcall(captureLocally) end
    if event == "PLAYER_ENTERING_WORLD" or event == "BAG_UPDATE_DELAYED" or
        event == "PLAYER_REGEN_ENABLED" then pcall(captureBagsLocally) end
end
captureFrame:SetScript("OnEvent", function(...) pcall(onEvent, ...) end)
local function onUpdate(_, delta)
    elapsed = elapsed + delta
    if elapsed >= 300 then
        elapsed = 0
        pcall(captureLocally)
        pcall(captureBagsLocally)
    end
end
captureFrame:SetScript("OnUpdate", function(...) pcall(onUpdate, ...) end)
