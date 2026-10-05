local path = ... or "../QuestCapture.lua"
local checks = 0
local function eq(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function clone(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = clone(x) end
    return out
end
local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local secret = setmetatable({}, { __mode = "k" })
_G = _G or _ENV
_G.issecretvalue = function(v) return secret[v] == true end
_G.issecrettable = function(v) return secret[v] == true end
_G.InCombatLockdown = function() return false end
_G.UnitGUID = function() return "Player-1234-ABCDEF12" end
_G.GetServerTime = function() return 1720000000 end
_G.GetBuildInfo = function() return "1.60.1", "70205" end
_G.MclarionWow_QuestStorageBudget = function() return true end
local rows = { { isHeader = true, questLogIndex = 1, title = "Area" },
    { isHeader = false, questLogIndex = 2, questID = 84 },
    { isHeader = false, questLogIndex = 3, questID = 42 } }
_G.C_QuestLog = {
    GetNumQuestLogEntries = function() return #rows, #rows - 1 end,
    GetInfo = function(i) return rows[i] end,
}
local chunk = assert(loadfile(path))
chunk()
local guid = UnitGUID("player")
local legacy = { schema = 2, characters = { [guid] = { "old" } },
    settings = { autoCombatLog = true } }
MclarionWowData = legacy
local oldLegacy = clone(legacy)
eq(MclarionWow_QuestAutoEnabled(), false, "automatic capture starts off")
eq(MclarionWowQuestData, nil, "no root on load")
local ok, reason = MclarionWow_CaptureQuests(true)
eq(ok, true, "manual captures without auto opt-in")
eq(reason, "saved", "manual result")
eq(MclarionWowQuestData.characters[guid][1],
    "MHWOWQ1|forever|1720000000|Player-1234-ABCDEF12|70205|active-log|3|2|42,84", "canonical sorted wire")
local reference = dofile("progression_contract.lua")
eq(reference.parseQuest(MclarionWowQuestData.characters[guid][1], guid) ~= nil,
    true, "writer output parses under existing test-only quest wire contract")
eq(equal(MclarionWowData, oldLegacy), true, "legacy schema and payload unchanged")
local root = MclarionWowQuestData
ok, reason = MclarionWow_CaptureQuests(true)
eq(ok, true, "duplicate scan accepted")
eq(reason, "unchanged", "same state deduplicates")
eq(MclarionWowQuestData, root, "unchanged does not rewrite root")
rows[3].questID = 43
ok, reason = MclarionWow_CaptureQuests(true)
eq(ok, true, "changed scan accepted")
eq(reason, "same-second", "changed state same second does not break timestamp ordering")
eq(MclarionWowQuestData, root, "same-second refusal leaves history")
GetServerTime = function() return 1720000001 end
ok, reason = MclarionWow_CaptureQuests(true)
eq(ok, true, "later changed state saved")
eq(reason, "saved", "later result")
eq(#MclarionWowQuestData.characters[guid], 2, "two observations")
local before = clone(MclarionWowQuestData)
local function refuse(label, mutate, reset)
    mutate()
    local safe, captured, why = pcall(MclarionWow_CaptureQuests, true)
    eq(safe, true, label .. " controlled refusal")
    eq(captured, nil, label .. " no capture")
    eq(type(why), "string", label .. " reason")
    eq(equal(MclarionWowQuestData, before), true, label .. " no mutation")
    reset()
end
refuse("view count changes", function()
    local calls = 0
    C_QuestLog.GetNumQuestLogEntries = function()
        calls = calls + 1
        return calls == 1 and 3 or 2
    end
end, function() C_QuestLog.GetNumQuestLogEntries = function() return #rows end end)
refuse("leaf changes between passes", function()
    local calls = 0
    C_QuestLog.GetInfo = function(i)
        calls = calls + 1
        if calls > 3 and i == 3 then return {isHeader=false,questLogIndex=3,questID=99} end
        return rows[i]
    end
end, function() C_QuestLog.GetInfo = function(i) return rows[i] end end)
refuse("header changes between passes", function()
    local calls = 0
    C_QuestLog.GetInfo = function(i)
        calls = calls + 1
        if calls > 3 and i == 1 then return {isHeader=true,questLogIndex=1,title="Elsewhere"} end
        return rows[i]
    end
end, function() C_QuestLog.GetInfo = function(i) return rows[i] end end)
refuse("duplicate ID", function() rows[3].questID = 84 end,
    function() rows[3].questID = 43 end)
refuse("missing header title", function() rows[1].title = nil end,
    function() rows[1].title = "Area" end)
refuse("protected leaf", function()
    local value = setmetatable({}, {__eq=function() error("secret inspected") end})
    secret[value] = true
    rows[3].questID = value
end, function() secret[rows[3].questID] = nil; rows[3].questID = 43 end)
refuse("over-limit rows", function()
    C_QuestLog.GetNumQuestLogEntries = function() return 129 end
end, function() C_QuestLog.GetNumQuestLogEntries = function() return #rows end end)
refuse("combat", function() InCombatLockdown = function() return true end end,
    function() InCombatLockdown = function() return false end end)
refuse("throwing getter", function() C_QuestLog.GetInfo = function() error("private") end end,
    function() C_QuestLog.GetInfo = function(i) return rows[i] end end)
local corrupted = clone(before)
corrupted.characters[guid][1] = "bad"
MclarionWowQuestData = corrupted
ok = MclarionWow_CaptureQuests(true)
eq(ok, nil, "corrupt previous record refused")
eq(MclarionWowQuestData, corrupted, "corrupt root not replaced")
MclarionWowQuestData = clone(before)
-- An invalid existing state must not be replaced or reinitialized.
MclarionWowQuestData = { schema = 99, characters = {} }
local invalid = MclarionWowQuestData
ok = MclarionWow_CaptureQuests(true)
eq(ok, nil, "unknown schema refused")
eq(MclarionWowQuestData, invalid, "unknown root untouched")
MclarionWowQuestData = clone(before)
local previous = MclarionWowQuestData
local function guarded(label, mutate, restore, entry, expected)
    local source = MclarionWowQuestData
    local snapshot = clone(source)
    mutate()
    local target = MclarionWowQuestData
    local safe, value, why = pcall(entry)
    eq(safe, true, label .. " does not throw")
    eq(value, nil, label .. " refuses")
    eq(why, expected or "Quest protected value refused.", label .. " fixed refusal")
    eq(MclarionWowQuestData, target, label .. " preserves target identity")
    eq(equal(source, snapshot), true, label .. " preserves source content")
    restore()
end
local savedSecret, savedSecretTable = issecretvalue, issecrettable
for _, primitive in ipairs({ "issecretvalue", "issecrettable" }) do
    local original = _G[primitive]
    guarded(primitive .. " absent", function() _G[primitive] = nil end,
        function() _G[primitive] = original end,
        function() return MclarionWow_CaptureQuests(true) end)
    guarded(primitive .. " throwing", function() _G[primitive] = function() error("private protection") end end,
        function() _G[primitive] = original end,
        function() return MclarionWow_SetAutoQuestCapture(true) end)
    _G[primitive] = nil
    local auto, errorText = MclarionWow_QuestAutoEnabled()
    eq(auto, false, primitive .. " absent auto disabled")
    eq(errorText, "Quest protected value refused.", primitive .. " absent auto reason")
    _G[primitive] = original
end
local dangerous = setmetatable({}, { __eq = function() error("protected compared") end,
    __index = function() error("protected indexed") end })
secret[dangerous] = true
guarded("protected root capture", function() MclarionWowQuestData = dangerous end,
    function() MclarionWowQuestData = previous end,
    function() return MclarionWow_CaptureQuests(true) end)
guarded("protected root setting", function() MclarionWowQuestData = dangerous end,
    function() MclarionWowQuestData = previous end,
    function() return MclarionWow_SetAutoQuestCapture(true) end)
MclarionWowQuestData = dangerous
local autoSafe, autoValue, autoReason = pcall(MclarionWow_QuestAutoEnabled)
eq(autoSafe, true, "protected root auto does not throw")
eq(autoValue, false, "protected root auto disabled")
eq(autoReason, "Quest protected value refused.", "protected root auto fixed refusal")
MclarionWowQuestData = previous
local originalTableCheck = issecrettable
issecrettable = function(v) return v == dangerous or originalTableCheck(v) end
secret[dangerous] = nil
guarded("table-only protected root", function() MclarionWowQuestData = dangerous end,
    function() MclarionWowQuestData = previous end,
    function() return MclarionWow_SetAutoQuestCapture(true) end)
issecrettable = originalTableCheck
secret[dangerous] = true
guarded("protected budget result", function()
    MclarionWow_QuestStorageBudget = function() return dangerous end
end, function() MclarionWow_QuestStorageBudget = function() return true end end,
    function() return MclarionWow_SetAutoQuestCapture(true) end)
guarded("protected budget result capture", function()
    MclarionWow_QuestStorageBudget = function() return dangerous end
    rows[3].questID = 44
    GetServerTime = function() return 1720000002 end
end, function()
    MclarionWow_QuestStorageBudget = function() return true end
    rows[3].questID = 43
    GetServerTime = function() return 1720000001 end
end, function() return MclarionWow_CaptureQuests(true) end)
local malformedSettings = clone(previous)
malformedSettings.settings.autoQuestCapture = "invalid"
MclarionWowQuestData = malformedSettings
local settingSafe, settingValue, settingReason = pcall(MclarionWow_SetAutoQuestCapture, true)
eq(settingSafe, true, "malformed setting does not throw")
eq(settingValue, nil, "malformed setting refused")
eq(settingReason, "Quest setting format refused.", "validation error not settings")
eq(MclarionWowQuestData, malformedSettings, "malformed setting root unchanged")
MclarionWowQuestData = previous
eq(issecretvalue, savedSecret, "secret primitive restored")
eq(issecrettable, savedSecretTable, "table primitive restored")
MclarionWow_QuestStorageBudget = function() return nil end
rows[3].questID = 44
GetServerTime = function() return 1720000002 end
ok = MclarionWow_CaptureQuests(true)
eq(ok, nil, "budget refusal")
eq(MclarionWowQuestData, previous, "budget refusal atomic")
MclarionWow_QuestStorageBudget = function() return true end
rows[3].questID = 43
ok, reason = MclarionWow_SetAutoQuestCapture(true)
eq(ok, true, "explicit auto opt-in")
eq(MclarionWow_QuestAutoEnabled(), true, "auto enabled")
eq(equal(MclarionWowData, oldLegacy), true, "setting does not migrate legacy root")
local countBeforeEmpty = C_QuestLog.GetNumQuestLogEntries
C_QuestLog.GetNumQuestLogEntries = function() return 0 end
local populated = MclarionWowQuestData
ok = MclarionWow_CaptureQuests(false)
eq(ok, nil, "automatic empty scan cannot supplant populated active log")
eq(MclarionWowQuestData, populated, "automatic empty refusal keeps valid history")
ok, reason = MclarionWow_CaptureQuests(true)
eq(ok, true, "manual empty observation may be explicitly confirmed")
eq(reason, "saved", "manual empty observation stored")
eq(MclarionWowQuestData.characters[guid][3]:match("|active%-log|0|0|$") ~= nil,
    true, "confirmed empty log is scoped, not a completion claim")
C_QuestLog.GetNumQuestLogEntries = countBeforeEmpty
MclarionWow_SetAutoQuestCapture(false)
eq(MclarionWow_QuestAutoEnabled(), false, "auto opt-out")
local disabledRoot = MclarionWowQuestData
ok = MclarionWow_CaptureQuests(false)
eq(ok, nil, "automatic call respects off setting")
eq(MclarionWowQuestData, disabledRoot, "disabled call does not rewrite")

local malformed = clone(MclarionWowQuestData)
malformed.characters[guid][4] = "MHWOWQ1|forever|1720000009|" .. guid ..
    "|70205|active-log|1|1|01"
MclarionWowQuestData = malformed
ok = MclarionWow_CaptureQuests(true)
eq(ok, nil, "sparse and noncanonical history refused")
eq(MclarionWowQuestData, malformed, "malformed history never overwritten")
MclarionWowQuestData = clone(disabledRoot)
local originalApi = C_QuestLog
local protected = setmetatable({}, { __index = function() error("secret indexed") end })
secret[protected] = true
C_QuestLog = protected
ok = MclarionWow_CaptureQuests(true)
eq(ok, nil, "protected namespace refuses")
C_QuestLog = originalApi
secret[protected] = nil

-- A bounded rolling history retains the newest 20 distinct states only.
for i = 1, 22 do
    rows[3].questID = 100 + i
    local stamp = 1720000100 + i
    GetServerTime = function() return stamp end
    ok, reason = MclarionWow_CaptureQuests(true)
    eq(ok, true, "rolling capture " .. i)
    eq(reason, "saved", "rolling state " .. i)
end
eq(#MclarionWowQuestData.characters[guid], 20, "history capped at twenty")
eq(MclarionWowQuestData.characters[guid][1]:match("|%d+,([0-9]+)$"), "103",
    "oldest rolled observation was removed")
local boundedRoot = MclarionWowQuestData
local oldCount, oldRead = C_QuestLog.GetNumQuestLogEntries, C_QuestLog.GetInfo
C_QuestLog.GetNumQuestLogEntries = function() return 102 end
C_QuestLog.GetInfo = function(i)
    if i == 1 then return { isHeader = true, questLogIndex = 1, title = "Zone" } end
    return { isHeader = false, questLogIndex = i, questID = i - 1 }
end
ok = MclarionWow_CaptureQuests(true)
eq(ok, nil, "101 leaves refuse rather than truncate")
eq(MclarionWowQuestData, boundedRoot, "over-limit state keeps history")
C_QuestLog.GetNumQuestLogEntries, C_QuestLog.GetInfo = oldCount, oldRead
MclarionWowQuestData = nil
eq(MclarionWow_QuestAutoEnabled(), false, "missing root remains off after reload")
print("Quest capture: " .. checks .. " assertions passed")
