local ADDON_NAME = ...

local function isSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
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
    if InCombatLockdown() then
        return nil, "MclarionWow will not export while you are in combat."
    end

    local serverTime = GetServerTime()
    local playerGuid = UnitGUID("player")
    local playerName = UnitName("player")
    local realmName = GetRealmName()
    local _, classFile = UnitClass("player")
    local level = UnitLevel("player")
    local mapId
    if C_Map and C_Map.GetBestMapForUnit then
        mapId = C_Map.GetBestMapForUnit("player")
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

    if not positiveInteger(serverTime) then
        return nil, "Server time is unavailable."
    end
    if type(playerGuid) ~= "string" or not playerGuid:match("^Player%-") then
        return nil, "A valid player GUID is unavailable."
    end
    if type(playerName) ~= "string" or playerName == "" then
        return nil, "Player name is unavailable."
    end
    if playerName:find("[%c]") then
        return nil, "Player name contains unsupported control characters."
    end
    if type(realmName) ~= "string" or realmName == "" then
        return nil, "Realm name is unavailable."
    end
    if realmName:find("[%c]") then
        return nil, "Realm name contains unsupported control characters."
    end
    if type(classFile) ~= "string" or classFile == "" then
        return nil, "Player class is unavailable."
    end
    if not positiveInteger(level) then
        return nil, "Player level must be positive."
    end
    if mapId == nil then
        mapId = 0
    elseif not nonnegativeInteger(mapId) then
        return nil, "Map ID is invalid."
    end
    if type(zoneText) ~= "string" then
        return nil, "Zone name is unavailable."
    end
    if zoneText:find("[%c]") then
        return nil, "Zone name contains unsupported control characters."
    end
    if not positiveInteger(build) then
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
        elseif not nonnegativeInteger(itemId) then
            return nil, "Inventory slot " .. slot .. " has an invalid item ID."
        end
        gearIds[slot] = tostring(itemId)
    end

    return table.concat({
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
    }, "|"), nil, playerGuid
end

-- Read-only compatibility probe. No item IDs, stacks, or bag state are saved
-- until the actual Forever client has been tested with its current APIs.
function MclarionWow_ProbeBags()
    if InCombatLockdown() then
        return nil, "Bag probe is unavailable during combat."
    end
    if type(issecretvalue) ~= "function" or type(issecrettable) ~= "function" then
        return nil, "Bag protection checks are unavailable."
    end
    if type(C_Container) ~= "table" or issecrettable(C_Container) then
        return nil, "Bag API is unavailable."
    end
    if type(C_Container.GetContainerNumSlots) ~= "function" or
        type(C_Container.GetContainerItemInfo) ~= "function" then
        return nil, "Bag API is unavailable."
    end

    local slotsTotal, occupied, distinct = 0, 0, 0
    local seen = {}
    for bag = 0, 4 do
        local slots = C_Container.GetContainerNumSlots(bag)
        if isSecret(slots) then
            return nil, "Bag slot count is protected by the client."
        end
        if not nonnegativeInteger(slots) or slots > 120 then
            return nil, "Bag slot count is unavailable."
        end
        slotsTotal = slotsTotal + slots
        for slot = 1, slots do
            local item = C_Container.GetContainerItemInfo(bag, slot)
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
                if not positiveInteger(itemId) or not positiveInteger(count) then
                    return nil, "Bag item value is invalid."
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
        slotsTotal, occupied, distinct)
end

local function saveSnapshot(guid, export)
    if MclarionWowData == nil then
        MclarionWowData = { schema = 1, characters = {} }
    elseif type(MclarionWowData) ~= "table" or MclarionWowData.schema ~= 1 or
        type(MclarionWowData.characters) ~= "table" then
        return nil, "Saved data has an unsupported format; it was not overwritten."
    end
    local snapshots = MclarionWowData.characters[guid]
    if snapshots == nil then
        snapshots = {}
        MclarionWowData.characters[guid] = snapshots
    end
    -- Time alone is not a meaningful character change. Keep local history bounded
    -- even when the periodic capture runs for hours without gear/zone changes.
    local details = export:match("^MHWOW1|forever|%d+|(.*)$")
    local previous = snapshots[#snapshots] and snapshots[#snapshots]:match("^MHWOW1|forever|%d+|(.*)$")
    if snapshots[#snapshots] ~= export and (details == nil or details ~= previous) then
        snapshots[#snapshots + 1] = export
        if #snapshots > 20 then
            table.remove(snapshots, 1)
        end
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

    local export, err, guid = MclarionWow_BuildExport()
    if export then
        local stored, storageError = saveSnapshot(guid, export)
        exportBox:SetText(stored and export or "Storage unavailable: " .. storageError)
    else
        exportBox:SetText("Export unavailable: " .. (err or "unknown error"))
    end
    window:Show()
    exportBox:Show()
    exportBox:SetFocus()
    exportBox:HighlightText()
end

SLASH_MCLARIONWOW1 = "/mhwow"
SlashCmdList.MCLARIONWOW = showExport

SLASH_MCLARIONWOWBAGS1 = "/mhwowbags"
SlashCmdList.MCLARIONWOWBAGS = function()
    local ok, report, err = pcall(MclarionWow_ProbeBags)
    print("MclarionWow: " .. (ok and (report or err) or "Bag probe unavailable."))
end

local captureFrame = CreateFrame("Frame")
local inWorld = false
local elapsed = 0
local function captureLocally()
    if not inWorld or InCombatLockdown() then return end
    local ok, export, _, guid = pcall(MclarionWow_BuildExport)
    if ok and export and guid then
        saveSnapshot(guid, export)
    end
end

for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED" }) do
    captureFrame:RegisterEvent(event)
end
captureFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then inWorld = true end
    captureLocally()
end)
captureFrame:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed >= 300 then
        elapsed = 0
        captureLocally()
    end
end)
