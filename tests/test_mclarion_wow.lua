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

local now = 1720000000
local inCombat = false
local secretValues = setmetatable({}, { __mode = "k" })
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

_G.UnitLevel = function() return 0 end
export, err = MclarionWow_BuildExport()
expectEqual(export, nil, "non-positive level blocks export")
_G.UnitLevel = function() return 80 end

_G.UnitGUID = function() return "Creature-0-0-0-0-1-0" end
export, err = MclarionWow_BuildExport()
expectEqual(export, nil, "non-player GUID blocks export")
_G.UnitGUID = function() return "Player-1234-ABCDEF12" end

expectTrue(type(SLASH_MCLARIONWOW1) == "string", "registers a slash command")
expectTrue(type(SlashCmdList.MCLARIONWOW) == "function", "slash command handler exists")
SlashCmdList.MCLARIONWOW()
local editBox
for _, frame in ipairs(frames) do
    if frame.frameType == "EditBox" then editBox = frame end
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
    MclarionWowData = saved
end

if failures > 0 then
    io.stderr:write(string.format("\n%d/%d assertions failed\n", failures, tests))
    os.exit(1)
end
io.stdout:write(string.format("\nAll %d assertions passed\n", tests))
