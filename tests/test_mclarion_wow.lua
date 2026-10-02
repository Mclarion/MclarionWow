local addonPath = ... or "../MclarionWow.lua"

local failures = 0
local tests = 0

local function expectEqual(actual, expected, message)
    tests = tests + 1
    if actual ~= expected then
        failures = failures + 1
        io.stderr:write(string.format("FAIL: %s\n  expected: %s\n  actual:   %s\n", message, tostring(expected), tostring(actual)))
    else
        io.stdout:write("PASS: " .. message .. "\n")
    end
end

local function expectTrue(value, message)
    expectEqual(value == true, true, message)
end

local function protectedSentinel()
    local function accessed() error("mock protected value was inspected") end
    return setmetatable({}, {
        __index = accessed,
        __tostring = accessed,
        __lt = accessed,
        __le = accessed,
        __add = accessed,
        __concat = accessed,
    })
end

local function sameData(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    for key, value in pairs(left) do
        if not sameData(value, right[key]) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

local now = 1720000000
local inCombat = false
local secretValues = setmetatable({}, { __mode = "k" })
local secretTables = setmetatable({}, { __mode = "k" })
local gear = {}
for slot = 1, 19 do gear[slot] = 1000 + slot end

_G = _G or _ENV
_G.GetServerTime = function() return now end
_G.UnitGUID = function(unit) assert(unit == "player"); return "Player-1234-ABCDEF12" end
_G.UnitName = function(unit) assert(unit == "player"); return "Name|Percent%" end
_G.GetRealmName = function() return "Realm|One%" end
_G.UnitClass = function(unit) assert(unit == "player"); return "Warrior", "WARRIOR", 1 end
_G.UnitLevel = function(unit) assert(unit == "player"); return 80 end
_G.C_Map = { GetBestMapForUnit = function(unit) assert(unit == "player"); return 2339 end }
_G.GetZoneText = function() return "Dornogal|Core" end
_G.GetInventoryItemID = function(unit, slot) assert(unit == "player"); return gear[slot] end
_G.GetBuildInfo = function() return "1.60.1", "70170", "Oct 1 2026", 16001 end
_G.InCombatLockdown = function() return inCombat end
_G.issecretvalue = function(value) return secretValues[value] == true end
_G.issecrettable = function(value) return secretTables[value] == true end
_G.C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end,
    GetContainerItemInfo = function(bag, slot)
        if bag == 0 and slot == 1 then return { itemID = 4242, stackCount = 3 } end
    end,
}

local frames = {}
_G.UIParent = {}
_G.SlashCmdList = {}
_G.CreateFrame = function(frameType, name, parent, template)
    local frame = {
        frameType = frameType,
        name = name,
        parent = parent,
        template = template,
        shown = false,
        scripts = {},
    }
    function frame:SetSize() end
    function frame:SetPoint() end
    function frame:SetFrameStrata() end
    function frame:SetMovable() end
    function frame:EnableMouse() end
    function frame:RegisterForDrag() end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    function frame:RegisterEvent(event)
        self.events = self.events or {}
        self.events[event] = true
    end
    function frame:StartMoving() end
    function frame:StopMovingOrSizing() end
    function frame:SetAutoFocus() end
    function frame:SetMultiLine() end
    function frame:SetFontObject() end
    function frame:SetTextInsets() end
    function frame:SetText(text) self.text = text end
    function frame:GetText() return self.text end
    function frame:HighlightText() self.highlighted = true end
    function frame:SetFocus() self.focused = true end
    function frame:ClearFocus() self.focused = false end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:SetNormalFontObject() end
    function frame:SetHighlightFontObject() end
    function frame:SetPushedTextOffset() end
    function frame:CreateFontString()
        local fontString = {}
        function fontString:SetPoint() end
        function fontString:SetText() end
        return fontString
    end
    frames[#frames + 1] = frame
    return frame
end
_G.ChatFontNormal = {}
_G.GameFontNormal = {}
_G.GameFontNormalLarge = {}
_G.GameFontHighlight = {}
_G.GameFontDisable = {}

local chunk, loadError = loadfile(addonPath)
if not chunk then
    io.stderr:write("FAIL: addon loads: " .. tostring(loadError) .. "\n")
    os.exit(1)
end
chunk("MclarionWow", {})

expectTrue(type(MclarionWow_BuildExport) == "function", "exports a testable snapshot builder")

expectTrue(type(MclarionWow_ProbeBags) == "function", "provides an out-of-combat read-only bag probe")
if type(MclarionWow_ProbeBags) == "function" then
    local report, bagError = MclarionWow_ProbeBags()
    expectEqual(bagError, nil, "bag probe has no error with plain own-bag values")
    expectTrue(type(report) == "string" and report:find("2 slots", 1, true) ~= nil and
        report:find("1 occupied", 1, true) ~= nil and report:find("1 distinct", 1, true) ~= nil,
        "bag probe reports counts only")
    expectTrue(report:find("4242", 1, true) == nil, "bag probe does not expose item IDs")
    inCombat = true
    report, bagError = MclarionWow_ProbeBags()
    expectEqual(report, nil, "bag probe refuses combat")
    inCombat = false
    local originalSlots = C_Container.GetContainerNumSlots
    local protectedSlots = protectedSentinel()
    secretValues[protectedSlots] = true
    C_Container.GetContainerNumSlots = function() return protectedSlots end
    local ok, protectedReport, protectedError = pcall(MclarionWow_ProbeBags)
    expectTrue(ok and protectedReport == nil, "mock secret slot count is rejected before arithmetic")
    expectEqual(protectedError, "Bag slot count is protected by the client.", "protected slot error is explicit")
    C_Container.GetContainerNumSlots = originalSlots
    secretValues[protectedSlots] = nil
    local originalInfo = C_Container.GetContainerItemInfo
    local protectedInfo = protectedSentinel()
    secretTables[protectedInfo] = true
    C_Container.GetContainerItemInfo = function() return protectedInfo end
    ok, protectedReport, protectedError = pcall(MclarionWow_ProbeBags)
    expectTrue(ok and protectedReport == nil, "mock secret item table is rejected before indexing")
    expectEqual(protectedError, "Bag item is protected by the client.", "protected table error is explicit")
    C_Container.GetContainerItemInfo = originalInfo
    secretTables[protectedInfo] = nil
    local protectedId = protectedSentinel()
    secretValues[protectedId] = true
    C_Container.GetContainerItemInfo = function() return { itemID = protectedId, stackCount = 3 } end
    ok, protectedReport, protectedError = pcall(MclarionWow_ProbeBags)
    expectTrue(ok and protectedReport == nil, "mock secret item ID is rejected before conversion")
    expectEqual(protectedError, "Bag item value is protected by the client.", "protected ID error is explicit")
    C_Container.GetContainerItemInfo = originalInfo
    secretValues[protectedId] = nil
    local protectedCount = protectedSentinel()
    secretValues[protectedCount] = true
    C_Container.GetContainerItemInfo = function() return { itemID = 4242, stackCount = protectedCount } end
    ok, protectedReport, protectedError = pcall(MclarionWow_ProbeBags)
    expectTrue(ok and protectedReport == nil, "mock secret stack count is rejected before arithmetic")
    expectEqual(protectedError, "Bag item value is protected by the client.", "protected count error is explicit")
    C_Container.GetContainerItemInfo = originalInfo
    secretValues[protectedCount] = nil
    C_Container.GetContainerItemInfo = function() return { itemID = 4242, stackCount = 0 } end
    report, bagError = MclarionWow_ProbeBags()
    expectEqual(report, nil, "invalid item count is rejected")
    C_Container.GetContainerItemInfo = originalInfo
    C_Container.GetContainerNumSlots = nil
    report, bagError = MclarionWow_ProbeBags()
    expectEqual(report, nil, "missing bag API does not fall back to unsafe calls")
    C_Container.GetContainerNumSlots = originalSlots
    expectTrue(type(SlashCmdList.MCLARIONWOWBAGS) == "function", "registers explicit bag probe command")
    local storedBeforeProbe = MclarionWowData
    MclarionWowData = { schema = 1, characters = { ["Player-1234-ABCDEF12"] = { "existing snapshot" } } }
    local expectedStorage = { schema = 1, characters = { ["Player-1234-ABCDEF12"] = { "existing snapshot" } } }
    SlashCmdList.MCLARIONWOWBAGS()
    expectTrue(sameData(MclarionWowData, expectedStorage), "bag probe leaves nested saved data unchanged")
    MclarionWowData = storedBeforeProbe
end

local originalCombatCheck = InCombatLockdown
local protectedCombat = protectedSentinel()
secretValues[protectedCombat] = true
_G.InCombatLockdown = function() return protectedCombat end
local safeProbe, blockedProbe, probeError = pcall(MclarionWow_ProbeBags)
expectTrue(safeProbe and blockedProbe == nil and type(probeError) == "string" and
    probeError:find("protected", 1, true) ~= nil, "protected combat status blocks bag reads")
local safeCharacter, blockedCharacter, characterError = pcall(MclarionWow_BuildExport)
expectTrue(safeCharacter and blockedCharacter == nil and type(characterError) == "string" and
    characterError:find("protected", 1, true) ~= nil, "protected combat status blocks character reads")
_G.InCombatLockdown = originalCombatCheck
secretValues[protectedCombat] = nil

expectTrue(type(MclarionWow_BuildBagExport) == "function", "builds a manual bag export")
if type(MclarionWow_BuildBagExport) == "function" then
    local bagExport, bagError = MclarionWow_BuildBagExport()
    expectEqual(bagError, nil, "plain bag data exports without error")
    expectEqual(bagExport, "MHWOWB1|forever|1720000000|Player-1234-ABCDEF12|4242:3|70170",
        "bag export contains only sorted own item totals and metadata")
    expectEqual(MclarionWowData, nil, "building a bag export does not save it")
    local originalSlots = C_Container.GetContainerNumSlots
    local originalInfo = C_Container.GetContainerItemInfo
    C_Container.GetContainerNumSlots = function(bag) return bag == 0 and 3 or 0 end
    C_Container.GetContainerItemInfo = function(bag, slot)
        if bag ~= 0 then return nil end
        if slot == 1 then return { itemID = 4242, stackCount = 3 } end
        if slot == 2 then return { itemID = 100, stackCount = 5 } end
        if slot == 3 then return { itemID = 4242, stackCount = 2 } end
    end
    bagExport = MclarionWow_BuildBagExport()
    expectEqual(bagExport, "MHWOWB1|forever|1720000000|Player-1234-ABCDEF12|100:5,4242:5|70170",
        "bag export sorts item IDs and sums stacks across slots")
    C_Container.GetContainerNumSlots = originalSlots
    C_Container.GetContainerItemInfo = originalInfo
end

local expectedGear = {}
for slot = 1, 19 do expectedGear[#expectedGear + 1] = tostring(1000 + slot) end
local expected = table.concat({
    "MHWOW1",
    "forever",
    tostring(now),
    "Player-1234-ABCDEF12",
    "Name%7CPercent%25",
    "Realm%7COne%25",
    "WARRIOR",
    "80",
    "2339",
    "Dornogal%7CCore",
    table.concat(expectedGear, ","),
    "70170",
}, "|")

local export, err = MclarionWow_BuildExport()
expectEqual(err, nil, "valid snapshot has no error")
expectEqual(export, expected, "builds exactly twelve escaped pipe-separated fields")
expectEqual(select(2, export:gsub("|", "")), 11, "export has exactly twelve fields")

local originalMap = C_Map
local protectedMap = protectedSentinel()
secretTables[protectedMap] = true
_G.C_Map = protectedMap
local safeMap, blockedMap, mapError = pcall(MclarionWow_BuildExport)
expectTrue(safeMap and blockedMap == nil and type(mapError) == "string" and
    mapError:find("protected", 1, true) ~= nil, "protected map API is not indexed")
_G.C_Map = originalMap
secretTables[protectedMap] = nil
local originalName = UnitName
_G.UnitName = function() return string.rep("n", 81) end
local oversizedName, nameError = MclarionWow_BuildExport()
expectTrue(oversizedName == nil and nameError ~= nil,
    "character export refuses text larger than the website parser accepts")
_G.UnitName = originalName
local normalTime = now
now = 253402300800
local futureExport = MclarionWow_BuildExport()
expectEqual(futureExport, nil, "timestamp outside website parser range is refused")
now = normalTime

gear[5] = nil
export, err = MclarionWow_BuildExport()
local parts = {}
for part in export:gmatch("([^|]+)") do parts[#parts + 1] = part end
local gearParts = {}
for id in parts[11]:gmatch("([^,]+)") do gearParts[#gearParts + 1] = id end
expectEqual(#gearParts, 19, "gear CSV always has nineteen entries")
expectEqual(gearParts[5], "0", "empty inventory slot exports as zero")
gear[5] = 1005

inCombat = true
export, err = MclarionWow_BuildExport()
expectEqual(export, nil, "combat blocks export")
expectTrue(type(err) == "string" and #err > 0, "combat returns a user-facing error")
inCombat = false

local originalName = _G.UnitName
_G.UnitName = function() local value = {}; secretValues[value] = true; return value end
export, err = MclarionWow_BuildExport()
expectEqual(export, nil, "secret text blocks export")
_G.UnitName = originalName

_G.UnitName = function() return "Invalid\nName" end
export, err = MclarionWow_BuildExport()
expectEqual(export, nil, "control characters block export")
_G.UnitName = originalName

local originalItem = gear[7]
secretValues[originalItem] = true
export, err = MclarionWow_BuildExport()
expectEqual(export, nil, "secret gear ID blocks export")
secretValues[originalItem] = nil
gear[7] = 2147483648
export, err = MclarionWow_BuildExport()
expectEqual(export, nil, "gear IDs beyond the website parser range are refused")
gear[7] = originalItem

local originalBuildInfo = _G.GetBuildInfo
local protectedBuild = {}
secretValues[protectedBuild] = true
_G.GetBuildInfo = function() return "1.60.1", protectedBuild, "Oct 1 2026", 16001 end
local buildOk, buildExport, buildError = pcall(MclarionWow_BuildExport)
expectTrue(buildOk and buildExport == nil and
    type(buildError) == "string" and buildError:find("protected", 1, true) ~= nil,
    "protected build refuses export without throwing")
_G.GetBuildInfo = originalBuildInfo
secretValues[protectedBuild] = nil

local originalMap = _G.C_Map.GetBestMapForUnit
local protectedMap = {}
secretValues[protectedMap] = true
_G.C_Map.GetBestMapForUnit = function() return protectedMap end
local mapOk, mapExport, mapError = pcall(MclarionWow_BuildExport)
expectTrue(mapOk and mapExport == nil and
    type(mapError) == "string" and mapError:find("protected", 1, true) ~= nil,
    "protected map refuses export without throwing")
_G.C_Map.GetBestMapForUnit = originalMap
secretValues[protectedMap] = nil

_G.UnitLevel = function() return 0 end
export, err = MclarionWow_BuildExport()
expectEqual(export, nil, "non-positive level blocks export")
_G.UnitLevel = function() return 80 end

_G.UnitGUID = function() return "Creature-0-0-0-0-1-0" end
export, err = MclarionWow_BuildExport()
expectEqual(export, nil, "non-player GUID blocks export")
_G.UnitGUID = function() return "Player-|bad" end
export, err = MclarionWow_BuildExport()
expectEqual(export, nil, "malformed player GUID does not add export fields")
_G.UnitGUID = function() return "Player-" .. string.rep("a", 71) end
export, err = MclarionWow_BuildExport()
expectEqual(export, nil, "character GUID exceeding website bound is refused")
_G.UnitGUID = function() return "Player-1234-ABCDEF12" end

expectTrue(type(SLASH_MCLARIONWOW1) == "string", "registers a slash command")
expectTrue(type(SlashCmdList.MCLARIONWOW) == "function", "slash command handler exists")
SlashCmdList.MCLARIONWOW()
local editBox
for _, frame in ipairs(frames) do
    if frame.frameType == "EditBox" then editBox = frame end
end
local function latestExportText()
    for index = #frames, 1, -1 do
        if frames[index].frameType == "EditBox" then return frames[index]:GetText() or "" end
    end
    return ""
end
expectTrue(editBox ~= nil and editBox.shown, "slash command shows selectable edit box")
expectEqual(editBox:GetText(), expected, "slash command populates current export")
expectTrue(editBox.highlighted, "slash command selects export for manual copy")

local saved = MclarionWowData
expectTrue(type(saved) == "table" and saved.schema == 1 and
    type(saved.characters) == "table" and
    type(saved.characters["Player-1234-ABCDEF12"]) == "table", "slash command saves a character snapshot locally")
if type(saved) == "table" and type(saved.characters) == "table" and
    type(saved.characters["Player-1234-ABCDEF12"]) == "table" then
    local snapshots = saved.characters["Player-1234-ABCDEF12"]
    expectEqual(snapshots[1], expected, "stored snapshot is the reviewed export")
    SlashCmdList.MCLARIONWOW()
    expectEqual(#snapshots, 1, "repeating an unchanged snapshot does not grow local storage")
    for _ = 1, 22 do
        now = now + 1
        gear[1] = gear[1] + 1
        SlashCmdList.MCLARIONWOW()
    end
    expectEqual(#snapshots, 20, "each character retains at most twenty snapshots")
    expectTrue(snapshots[1]:find("|" .. tostring(now - 19) .. "|", 1, true) ~= nil,
        "oldest local snapshots are pruned")
    chunk("MclarionWow", {})
    expectTrue(MclarionWowData == saved, "saved data survives addon reload")
    SlashCmdList.MCLARIONWOW()
    expectEqual(#snapshots, 20, "reloaded addon deduplicates current snapshot")
    inCombat = true
    SlashCmdList.MCLARIONWOW()
    expectEqual(#snapshots, 20, "combat does not store data")
    inCombat = false
    MclarionWowData = { schema = 2, characters = {} }
    local unsupported = MclarionWowData
    SlashCmdList.MCLARIONWOW()
    expectTrue(MclarionWowData == unsupported, "unknown storage schema is not overwritten")
    local touchedCharacterStorage = false
    local protectedStorage = setmetatable({}, { __index = function()
        touchedCharacterStorage = true
        error("protected character storage was indexed")
    end })
    secretTables[protectedStorage] = true
    MclarionWowData = protectedStorage
    local clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and not touchedCharacterStorage,
        "character capture rejects protected saved data before indexing")
    expectEqual(MclarionWowData, protectedStorage, "character capture preserves protected storage")
    secretTables[protectedStorage] = nil
    MclarionWowData = saved
    local originalCharacters = saved.characters
    saved.characters = protectedStorage
    secretTables[protectedStorage] = true
    touchedCharacterStorage = false
    clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and not touchedCharacterStorage,
        "character capture rejects protected character map before indexing")
    saved.characters = originalCharacters
    secretTables[protectedStorage] = nil
    local previousHistory = originalCharacters["Player-1234-ABCDEF12"]
    local protectedHistory = setmetatable({}, { __len = function()
        touchedCharacterStorage = true
        error("protected character history length was read")
    end })
    originalCharacters["Player-1234-ABCDEF12"] = protectedHistory
    secretTables[protectedHistory] = true
    touchedCharacterStorage = false
    clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and not touchedCharacterStorage,
        "character capture refuses protected history before reading length")
    originalCharacters["Player-1234-ABCDEF12"] = previousHistory
    secretTables[protectedHistory] = nil
    local malformedHistory = setmetatable({}, { __len = function()
        error("malformed character history")
    end })
    originalCharacters["Player-1234-ABCDEF12"] = malformedHistory
    clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and latestExportText():find("Storage unavailable", 1, true) ~= nil,
        "manual character export contains unexpected storage errors")
    originalCharacters["Player-1234-ABCDEF12"] = previousHistory
    local previousEntry = previousHistory[#previousHistory]
    local protectedEntry = protectedSentinel()
    secretValues[protectedEntry] = true
    previousHistory[#previousHistory] = protectedEntry
    clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and latestExportText():find("protected", 1, true) ~= nil,
        "character capture refuses protected history entries")
    previousHistory[#previousHistory] = previousEntry
    secretValues[protectedEntry] = nil
    local previousSchema = saved.schema
    local protectedSchema = protectedSentinel()
    secretValues[protectedSchema] = true
    saved.schema = protectedSchema
    clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and latestExportText():find("protected", 1, true) ~= nil,
        "character capture checks protected storage schema before comparing")
    saved.schema = previousSchema
    secretValues[protectedSchema] = nil
    local oversizedHistory = {}
    for index = 1, 21 do oversizedHistory[index] = expected end
    originalCharacters["Player-1234-ABCDEF12"] = oversizedHistory
    clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and #oversizedHistory == 21 and
        latestExportText():find("Storage unavailable", 1, true) ~= nil,
        "oversized pre-existing character history is left unchanged")
    local extraKeyHistory = { expected, unexpected = expected }
    originalCharacters["Player-1234-ABCDEF12"] = extraKeyHistory
    clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and #extraKeyHistory == 1 and extraKeyHistory[2] == nil and
        latestExportText():find("Storage unavailable", 1, true) ~= nil,
        "character history with an extra key is rejected unchanged")
    local sparseHistory = { [1] = expected, [3] = expected }
    originalCharacters["Player-1234-ABCDEF12"] = sparseHistory
    clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and sparseHistory[2] == nil and sparseHistory[4] == nil and
        latestExportText():find("Storage unavailable", 1, true) ~= nil,
        "sparse character history is rejected unchanged")
    local interiorHole = { [1] = expected, [2] = expected, [4] = expected }
    originalCharacters["Player-1234-ABCDEF12"] = interiorHole
    clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and interiorHole[3] == nil and interiorHole[5] == nil and
        latestExportText():find("Storage unavailable", 1, true) ~= nil,
        "interior character-history hole is rejected unchanged")
    local extraProtectedValue = protectedSentinel()
    secretValues[extraProtectedValue] = true
    local protectedExtraHistory = { expected, unexpected = extraProtectedValue }
    originalCharacters["Player-1234-ABCDEF12"] = protectedExtraHistory
    clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and protectedExtraHistory[2] == nil and
        latestExportText():find("protected", 1, true) ~= nil,
        "protected extra character-history entry is checked before use")
    secretValues[extraProtectedValue] = nil
    local cappedHistory = {}
    for index = 1, 20 do cappedHistory[index] = expected end
    cappedHistory.unexpected = expected
    originalCharacters["Player-1234-ABCDEF12"] = cappedHistory
    clean = pcall(SlashCmdList.MCLARIONWOW)
    expectTrue(clean and cappedHistory[20] == expected and
        latestExportText():find("Storage unavailable", 1, true) ~= nil,
        "full character history with an extra key cannot rotate")
    originalCharacters["Player-1234-ABCDEF12"] = previousHistory
end

expectTrue(type(SlashCmdList.MCLARIONWOWBAGSEXPORT) == "function",
    "registers a manual bag export command")
if type(SlashCmdList.MCLARIONWOWBAGSEXPORT) == "function" then
    local bagExport = MclarionWow_BuildBagExport()
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    local bagEditBox
    for _, frame in ipairs(frames) do
        if frame.frameType == "EditBox" then bagEditBox = frame end
    end
    expectEqual(bagEditBox:GetText(), bagExport, "manual bag export is selectable for player review")
    local bagHistory = MclarionWowData.bags["Player-1234-ABCDEF12"]
    expectEqual(bagHistory[1], bagExport, "reviewed bag export is saved locally")
    now = now + 1
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectEqual(#bagHistory, 1, "unchanged bag totals do not fill history")
    expectEqual(#MclarionWowData.characters["Player-1234-ABCDEF12"], 20,
        "bag capture does not change gear history")
    local originalBagInfo = C_Container.GetContainerItemInfo
    for index = 1, 22 do
        now = now + 1
        C_Container.GetContainerItemInfo = function(bag, slot)
            if bag == 0 and slot == 1 then
                return { itemID = 4242, stackCount = 3 + index }
            end
        end
        SlashCmdList.MCLARIONWOWBAGSEXPORT()
    end
    C_Container.GetContainerItemInfo = originalBagInfo
    expectEqual(#bagHistory, 20, "bag history retains at most twenty distinct states")
    expectTrue(bagHistory[1]:find("|4242:6|", 1, true) ~= nil,
        "bag history drops the oldest inventory states")
    local latestBag = bagHistory[#bagHistory]
    local secretItem = protectedSentinel()
    secretValues[secretItem] = true
    C_Container.GetContainerItemInfo = function(bag, slot)
        if bag == 0 and slot == 1 then return { itemID = secretItem, stackCount = 3 } end
    end
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectEqual(bagHistory[#bagHistory], latestBag, "secret bag item never enters local history")
    expectTrue(not bagEditBox:GetText():find("MHWOWB1", 1, true),
        "secret bag item never enters the copy window")
    C_Container.GetContainerItemInfo = originalBagInfo
    secretValues[secretItem] = nil
    inCombat = true
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectEqual(bagHistory[#bagHistory], latestBag, "combat cannot store a bag snapshot")
    inCombat = false
    local priorStorage = MclarionWowData
    local unknownStorage = { schema = 99, characters = {}, bags = {} }
    MclarionWowData = unknownStorage
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectEqual(MclarionWowData, unknownStorage, "unknown bag storage schema is not replaced")
    expectEqual(next(unknownStorage.bags), nil, "unknown bag storage schema is not written")
    MclarionWowData = priorStorage
    local touchedProtectedStorage = false
    local protectedStorage = setmetatable({}, { __index = function()
        touchedProtectedStorage = true
        error("protected storage was indexed")
    end })
    secretTables[protectedStorage] = true
    MclarionWowData = protectedStorage
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectEqual(touchedProtectedStorage, false, "protected saved data is rejected before indexing")
    expectEqual(MclarionWowData, protectedStorage, "protected saved data is not overwritten")
    MclarionWowData = priorStorage
    secretTables[protectedStorage] = nil
    local previousBagMap = priorStorage.bags
    local touchedProtectedBags = false
    local protectedBags = setmetatable({}, { __index = function()
        touchedProtectedBags = true
        error("protected bag map was indexed")
    end })
    secretTables[protectedBags] = true
    priorStorage.bags = protectedBags
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectEqual(touchedProtectedBags, false, "protected bag map is rejected before indexing")
    expectEqual(priorStorage.bags, protectedBags, "protected bag map is not overwritten")
    priorStorage.bags = previousBagMap
    secretTables[protectedBags] = nil
    local priorHistory = previousBagMap["Player-1234-ABCDEF12"]
    local touchedProtectedHistory = false
    local protectedHistory = setmetatable({}, { __len = function()
        touchedProtectedHistory = true
        error("protected bag history length was read")
    end })
    secretTables[protectedHistory] = true
    previousBagMap["Player-1234-ABCDEF12"] = protectedHistory
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectEqual(touchedProtectedHistory, false, "protected history is rejected before reading it")
    expectEqual(previousBagMap["Player-1234-ABCDEF12"], protectedHistory,
        "protected bag history is not overwritten")
    previousBagMap["Player-1234-ABCDEF12"] = priorHistory
    secretTables[protectedHistory] = nil
    local previousBagEntry = priorHistory[#priorHistory]
    local protectedBagEntry = protectedSentinel()
    secretValues[protectedBagEntry] = true
    priorHistory[#priorHistory] = protectedBagEntry
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectTrue(latestExportText():find("protected", 1, true) ~= nil,
        "bag capture checks protected history entries before use")
    priorHistory[#priorHistory] = previousBagEntry
    secretValues[protectedBagEntry] = nil
    local oversizedBagHistory = {}
    for index = 1, 21 do oversizedBagHistory[index] = previousBagEntry end
    previousBagMap["Player-1234-ABCDEF12"] = oversizedBagHistory
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectTrue(#oversizedBagHistory == 21 and
        latestExportText():find("Storage unavailable", 1, true) ~= nil,
        "oversized pre-existing bag history is left unchanged")
    local extraKeyBagHistory = { previousBagEntry, unexpected = previousBagEntry }
    previousBagMap["Player-1234-ABCDEF12"] = extraKeyBagHistory
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectTrue(#extraKeyBagHistory == 1 and extraKeyBagHistory[2] == nil and
        latestExportText():find("Storage unavailable", 1, true) ~= nil,
        "bag history with an extra key is rejected unchanged")
    local sparseBagHistory = { [1] = previousBagEntry, [3] = previousBagEntry }
    previousBagMap["Player-1234-ABCDEF12"] = sparseBagHistory
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectTrue(sparseBagHistory[2] == nil and sparseBagHistory[4] == nil and
        latestExportText():find("Storage unavailable", 1, true) ~= nil,
        "sparse bag history is rejected unchanged")
    local bagInteriorHole = { [1] = previousBagEntry, [2] = previousBagEntry,
        [4] = previousBagEntry }
    previousBagMap["Player-1234-ABCDEF12"] = bagInteriorHole
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectTrue(bagInteriorHole[3] == nil and bagInteriorHole[5] == nil and
        latestExportText():find("Storage unavailable", 1, true) ~= nil,
        "interior bag-history hole is rejected unchanged")
    local protectedBagKey = protectedSentinel()
    secretValues[protectedBagKey] = true
    local protectedKeyHistory = { [1] = previousBagEntry, [protectedBagKey] = previousBagEntry }
    previousBagMap["Player-1234-ABCDEF12"] = protectedKeyHistory
    SlashCmdList.MCLARIONWOWBAGSEXPORT()
    expectTrue(protectedKeyHistory[2] == nil and
        latestExportText():find("protected", 1, true) ~= nil,
        "protected extra bag-history key is checked before comparing")
    secretValues[protectedBagKey] = nil
    previousBagMap["Player-1234-ABCDEF12"] = priorHistory
end

-- Automatic capture remains local to WoW; it never transfers data to the site.
MclarionWowData = { schema = 1, characters = {} }
chunk("MclarionWow", {})
local captureFrame
for _, frame in ipairs(frames) do
    if frame.events and frame.events.PLAYER_ENTERING_WORLD then captureFrame = frame end
end
expectTrue(captureFrame ~= nil, "registers an automatic capture frame")
if captureFrame then
    now = now + 1
    captureFrame.scripts.OnEvent(captureFrame, "PLAYER_ENTERING_WORLD")
    local snapshots = MclarionWowData.characters["Player-1234-ABCDEF12"]
    expectEqual(snapshots and #snapshots, 1, "entering the world stores a local snapshot")
    expectTrue(captureFrame.events.BAG_UPDATE_DELAYED,
        "registers the coalesced own-bag update event")
    local bagSnapshots = MclarionWowData.bags and MclarionWowData.bags["Player-1234-ABCDEF12"]
    expectEqual(bagSnapshots and #bagSnapshots, 1, "entering the world stores a bag snapshot")
    local originalBagInfo = C_Container.GetContainerItemInfo
    now = now + 1
    C_Container.GetContainerItemInfo = function(bag, slot)
        if bag == 0 and slot == 1 then return { itemID = 4242, stackCount = 4 } end
    end
    captureFrame.scripts.OnEvent(captureFrame, "BAG_UPDATE_DELAYED")
    expectEqual(#bagSnapshots, 2, "bag update stores a changed inventory total")
    expectTrue(bagSnapshots[2]:find("|4242:4|", 1, true) ~= nil,
        "bag update stores aggregate counts, not inferred loot")
    captureFrame.scripts.OnEvent(captureFrame, "BAG_UPDATE_DELAYED")
    expectEqual(#bagSnapshots, 2, "repeating an unchanged bag event does not grow history")
    inCombat = true
    C_Container.GetContainerItemInfo = function(bag, slot)
        if bag == 0 and slot == 1 then return { itemID = 4242, stackCount = 5 } end
    end
    captureFrame.scripts.OnEvent(captureFrame, "BAG_UPDATE_DELAYED")
    expectEqual(#bagSnapshots, 2, "bag capture refuses combat")
    inCombat = false
    captureFrame.scripts.OnEvent(captureFrame, "PLAYER_REGEN_ENABLED")
    expectEqual(#bagSnapshots, 3, "after combat, pending bag change can be captured")
    C_Container.GetContainerItemInfo = originalBagInfo
    now = now + 300
    captureFrame.scripts.OnUpdate(captureFrame, 300)
    expectEqual(#snapshots, 1, "unchanged periodic capture does not fill history")
    gear[1] = 9001
    captureFrame.scripts.OnEvent(captureFrame, "PLAYER_EQUIPMENT_CHANGED")
    expectEqual(#snapshots, 2, "equipment change stores a new snapshot")
    expectTrue(snapshots[2]:find("|9001,", 1, true) ~= nil,
        "new snapshot carries changed equipment")
    inCombat = true
    gear[1] = 9002
    captureFrame.scripts.OnUpdate(captureFrame, 300)
    expectEqual(#snapshots, 2, "periodic capture skips combat")
    inCombat = false
    captureFrame.scripts.OnEvent(captureFrame, "PLAYER_REGEN_ENABLED")
    expectEqual(#snapshots, 3, "after combat, pending equipment can be captured")
    local characterCount, bagCount = #snapshots, #bagSnapshots
    local originalCombat = InCombatLockdown
    _G.InCombatLockdown = function() error("combat API unavailable") end
    local eventSafe = pcall(captureFrame.scripts.OnEvent, captureFrame, "PLAYER_REGEN_ENABLED")
    local updateSafe = pcall(captureFrame.scripts.OnUpdate, captureFrame, 300)
    expectTrue(eventSafe and updateSafe and #snapshots == characterCount and
        #bagSnapshots == bagCount,
        "automatic events contain combat API failures without writing")
    _G.InCombatLockdown = originalCombat
end

if failures > 0 then
    io.stderr:write(string.format("\n%d/%d assertions failed\n", failures, tests))
    os.exit(1)
end
io.stdout:write(string.format("\nAll %d assertions passed\n", tests))
