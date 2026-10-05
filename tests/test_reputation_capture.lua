local path = ... or "../ReputationCapture.lua"
local checks = 0
local function eq(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function clone(v)
    if type(v) ~= "table" then return v end
    local copy = {}
    for k, x in pairs(v) do copy[k] = clone(x) end
    return copy
end
local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
_G = _G or _ENV
local protected = setmetatable({}, {__mode = "k"})
_G.issecretvalue = function(v) return protected[v] == true end
_G.issecrettable = function(v) return protected[v] == true end
_G.InCombatLockdown = function() return false end
_G.UnitGUID = function() return "Player-1234-ABCDEF12" end
local now = 1720000000
_G.GetServerTime = function() return now end
_G.GetBuildInfo = function() return "1.60.1", "70205" end
_G.MclarionWow_ReputationStorageBudget = function() return true end
local rows = {
    {isHeader=true, isHeaderWithRep=false, isCollapsed=false, name="Area"},
    {isHeader=false, isHeaderWithRep=false, isCollapsed=false, factionID=200,
        reaction=5, currentReactionThreshold=3000, nextReactionThreshold=9000,
        currentStanding=4200, isAccountWide=false},
    {isHeader=false, isHeaderWithRep=false, isCollapsed=false, factionID=100,
        reaction=4, currentReactionThreshold=0, nextReactionThreshold=3000,
        currentStanding=1200, isAccountWide=false},
}
local count = function() return #rows end
local read = function(i) return rows[i] end
_G.C_Reputation = {GetNumFactions=count, GetFactionDataByIndex=read}
assert(loadfile(path))()
local guid = UnitGUID("player")
local legacy = {schema=2, settings={autoCombatLog=true}, characters={[guid]={"old"}}}
MclarionWowData = legacy
local legacyBefore = clone(legacy)
eq(MclarionWow_ReputationAutoEnabled(), false, "off by default")
eq(MclarionWowReputationData, nil, "load has no write")
local ok, reason = MclarionWow_CaptureReputation(false)
eq(ok, nil, "auto capture requires opt-in")
eq(MclarionWowReputationData, nil, "auto-off no root")
ok, reason = MclarionWow_CaptureReputation(true)
eq(ok, true, "manual capture")
eq(reason, "saved", "manual saved")
local wire = "MHWOWR1|forever|1720000000|" .. guid ..
    "|70205|visible-ui|3|2|0|0|100:4:0:3000:1200;200:5:3000:9000:4200"
eq(MclarionWowReputationData.characters[guid][1], wire, "canonical sorted wire")
local contract = dofile("progression_contract.lua")
local parsed = contract.parseReputation(wire, guid)
eq(parsed ~= nil, true, "existing R1 parser accepts wire")
eq(contract.characterReputationEligible({{id=100,isAccountWide=false},
    {id=200,isAccountWide=false}}, wire, guid), true, "character-only provenance matches wire")
eq(same(legacy, legacyBefore), true, "schema-2 unchanged")
local original = MclarionWowReputationData
ok, reason = MclarionWow_CaptureReputation(true)
eq(ok, true, "duplicate accepted")
eq(reason, "unchanged", "duplicate dedup")
eq(MclarionWowReputationData, original, "dedup avoids write")
rows[3].currentStanding = 1201
ok, reason = MclarionWow_CaptureReputation(true)
eq(ok, true, "same second accepted without write")
eq(reason, "same-second", "same-second ordering")
eq(MclarionWowReputationData, original, "same-second preserves root")
now = now + 1
ok, reason = MclarionWow_CaptureReputation(true)
eq(ok, true, "changed standing captured")
eq(reason, "saved", "changed state saved")
eq(#MclarionWowReputationData.characters[guid], 2, "two observations")
eq(MclarionWowReputationData.characters[guid][1], wire, "old state preserved")
local function refuse(label, change, restore)
    local before = MclarionWowReputationData
    local snapshot = clone(before)
    change()
    local safe, result, why = pcall(MclarionWow_CaptureReputation, true)
    eq(safe, true, label .. " controlled refusal")
    eq(result, nil, label .. " refused")
    eq(type(why), "string", label .. " has reason")
    eq(MclarionWowReputationData, before, label .. " same root")
    eq(same(before, snapshot), true, label .. " old data unmodified")
    restore()
end
refuse("account-wide", function() rows[3].isAccountWide = true end,
    function() rows[3].isAccountWide = false end)
refuse("unknown provenance", function() rows[3].isAccountWide = nil end,
    function() rows[3].isAccountWide = false end)
refuse("nonboolean provenance", function() rows[3].isAccountWide = 0 end,
    function() rows[3].isAccountWide = false end)
refuse("protected provenance", function()
    local token = {}; protected[token] = true; rows[3].isAccountWide = token
end, function() protected[rows[3].isAccountWide] = nil; rows[3].isAccountWide = false end)
refuse("protected row", function() protected[rows[3]] = true end,
    function() protected[rows[3]] = nil end)
refuse("protected header name", function()
    local token = {}; protected[token] = true; rows[1].name = token
end, function() protected[rows[1].name] = nil; rows[1].name = "Area" end)
refuse("missing header identity", function() rows[1].name = nil end,
    function() rows[1].name = "Area" end)
refuse("invalid header flag", function() rows[1].isCollapsed = nil end,
    function() rows[1].isCollapsed = false end)
refuse("leaf with header-only flag", function() rows[3].isHeaderWithRep = true end,
    function() rows[3].isHeaderWithRep = false end)
refuse("collapsed leaf", function() rows[3].isCollapsed = true end,
    function() rows[3].isCollapsed = false end)
refuse("invalid reaction", function() rows[3].reaction = 17 end,
    function() rows[3].reaction = 4 end)
refuse("NaN standing", function() rows[3].currentStanding = 0/0 end,
    function() rows[3].currentStanding = 1201 end)
refuse("interval", function() rows[3].currentStanding = 3001 end,
    function() rows[3].currentStanding = 1201 end)
refuse("duplicate leaf", function() rows[3].factionID = 200 end,
    function() rows[3].factionID = 100 end)
refuse("count change", function()
    local calls = 0
    C_Reputation.GetNumFactions = function() calls=calls+1; return calls == 1 and 3 or 2 end
end, function() C_Reputation.GetNumFactions = count end)
refuse("leaf mutation between scans", function()
    local calls = 0
    C_Reputation.GetFactionDataByIndex = function(i)
        calls = calls + 1
        if calls > 3 and i == 3 then
            local changed = clone(rows[3]); changed.currentStanding = 1202; return changed
        end
        return rows[i]
    end
end, function() C_Reputation.GetFactionDataByIndex = read end)
refuse("header mutation between scans", function()
    local calls = 0
    C_Reputation.GetFactionDataByIndex = function(i)
        calls = calls + 1
        if calls > 3 and i == 1 then
            return {isHeader=true,isHeaderWithRep=false,isCollapsed=false,name="Other"}
        end
        return rows[i]
    end
end, function() C_Reputation.GetFactionDataByIndex = read end)
refuse("reordered leaves", function()
    local calls = 0
    C_Reputation.GetFactionDataByIndex = function(i)
        calls = calls + 1
        if calls > 3 and i > 1 then return rows[5-i] end
        return rows[i]
    end
end, function() C_Reputation.GetFactionDataByIndex = read end)
refuse("throwing getter", function()
    C_Reputation.GetFactionDataByIndex = function() error("private") end
end, function() C_Reputation.GetFactionDataByIndex = read end)
refuse("row count over limit", function()
    C_Reputation.GetNumFactions = function() return 257 end
end, function() C_Reputation.GetNumFactions = count end)
refuse("protected budget result", function()
    now = now + 1; rows[3].currentStanding = 1202
    local token = {}; protected[token] = true
    MclarionWow_ReputationStorageBudget = function() return token end
end, function()
    rows[3].currentStanding = 1201
    MclarionWow_ReputationStorageBudget = function() return true end
end)
refuse("missing secret primitive", function() issecretvalue = nil end,
    function() issecretvalue = function(v) return protected[v] == true end end)
refuse("missing table primitive", function() issecrettable = nil end,
    function() issecrettable = function(v) return protected[v] == true end end)
refuse("combat", function() InCombatLockdown = function() return true end end,
    function() InCombatLockdown = function() return false end end)
refuse("missing combat", function() InCombatLockdown = nil end,
    function() InCombatLockdown = function() return false end end)
local namespace = C_Reputation
refuse("protected namespace", function() protected[namespace] = true end,
    function() protected[namespace] = nil end)
refuse("missing API", function() C_Reputation = nil end,
    function() C_Reputation = namespace end)
local opaque = setmetatable({}, {__eq=function() error("protected root compared") end})
protected[opaque] = true
local savedRoot = MclarionWowReputationData
MclarionWowReputationData = opaque
ok, reason = MclarionWow_CaptureReputation(true)
eq(ok, nil, "protected root refused")
eq(reason, "Reputation storage protected.", "protected root checked before nil")
eq(MclarionWowReputationData, opaque, "protected root untouched")
MclarionWowReputationData = savedRoot
protected[opaque] = nil
refuse("budget missing", function()
    now = now + 1; rows[3].currentStanding = 1202
    MclarionWow_ReputationStorageBudget = nil
end, function()
    MclarionWow_ReputationStorageBudget = function() return true end
    rows[3].currentStanding = 1201
end)
refuse("owner changed before commit", function()
    local calls = 0
    UnitGUID = function() calls=calls+1; return calls == 1 and guid or "Player-1234-DIFFERENT" end
    now = now + 1; rows[3].currentStanding = 1202
end, function()
    UnitGUID = function() return guid end; rows[3].currentStanding = 1201
end)
local validRoot = MclarionWowReputationData
local bad = clone(validRoot)
bad.characters[guid][1] = "bad"
MclarionWowReputationData = bad
ok = MclarionWow_CaptureReputation(true)
eq(ok, nil, "corrupt history refused")
eq(MclarionWowReputationData, bad, "corrupt root not replaced")
MclarionWowReputationData = validRoot
bad = {schema=3, settings={}, characters={}}
MclarionWowReputationData = bad
ok = MclarionWow_CaptureReputation(true)
eq(ok, nil, "unknown root schema refused")
eq(MclarionWowReputationData, bad, "unknown root preserved")
MclarionWowReputationData = validRoot
local beforeSetting = MclarionWowReputationData
ok, reason = MclarionWow_SetAutoReputationCapture(true)
eq(ok, true, "separate explicit opt-in")
eq(MclarionWow_ReputationAutoEnabled(), true, "auto enabled")
eq(beforeSetting == MclarionWowReputationData, false, "setting copy-on-write")
eq(same(beforeSetting.characters, MclarionWowReputationData.characters), true,
    "setting retains histories")
eq(same(legacy, legacyBefore), true, "setting does not migrate legacy")
local enabledRoot = MclarionWowReputationData
now = now + 1
rows[3].currentStanding = 1202
ok, reason = MclarionWow_CaptureReputation(false)
eq(ok, true, "auto capture after consent")
eq(reason, "saved", "new state auto saved")
local history = MclarionWowReputationData.characters[guid]
eq(#history, 3, "auto history appended")
eq(#enabledRoot.characters[guid], 2, "previous root remains immutable")
ok = MclarionWow_SetAutoReputationCapture(false)
eq(ok, true, "opt-out")
local disabled = MclarionWowReputationData
ok = MclarionWow_CaptureReputation(false)
eq(ok, nil, "opt-out enforced")
eq(MclarionWowReputationData, disabled, "off does not rewrite")
-- Header counters can overlap; they do not imply unobserved children exist.
rows[1].isHeaderWithRep, rows[1].isCollapsed = true, true
now = now + 1
ok, reason = MclarionWow_CaptureReputation(true)
eq(ok, true, "bounded header attributes captured")
eq(MclarionWowReputationData.characters[guid][4]:match("|3|2|1|1|" ) ~= nil,
    true, "overlapping header flags counted")
rows[1].isHeaderWithRep, rows[1].isCollapsed = false, false
-- A full, stable view with more than 200 leaves is refused, never truncated.
local oldRows = rows
rows = {}
for i = 1, 201 do
    rows[i] = {isHeader=false,isHeaderWithRep=false,isCollapsed=false,
        factionID=i,reaction=4,currentReactionThreshold=0,
        nextReactionThreshold=3000,currentStanding=1,isAccountWide=false}
end
local over = MclarionWowReputationData
ok = MclarionWow_CaptureReputation(true)
eq(ok, nil, "201 leaves refused")
eq(MclarionWowReputationData, over, "leaf overflow keeps history")
rows = oldRows
for i = 1, 22 do
    now = now + 1
    rows[3].currentStanding = 1300 + i
    ok, reason = MclarionWow_CaptureReputation(true)
    eq(ok, true, "rolling capture " .. i)
    eq(reason, "saved", "rolling state " .. i)
end
eq(#MclarionWowReputationData.characters[guid], 20, "history bounded to 20")
eq(MclarionWowReputationData.characters[guid][1]:match(":(%d+);200:"), "1303",
    "oldest retained rolling state")
local maxed = MclarionWowReputationData
local poisoned = clone(maxed)
poisoned.characters[guid][5] = "MHWOWR1|forever|bad"
MclarionWowReputationData = poisoned
ok = MclarionWow_CaptureReputation(true)
eq(ok, nil, "invalid retained record refused")
eq(MclarionWowReputationData, poisoned, "invalid record not overwritten")
MclarionWowReputationData = maxed
-- The budget callback cannot smuggle an invalid candidate into storage.
local stable = MclarionWowReputationData
now = now + 1
rows[3].currentStanding = 1400
MclarionWow_ReputationStorageBudget = function(candidate)
    candidate.characters[guid][1] = "corrupted"
    return true
end
ok = MclarionWow_CaptureReputation(true)
eq(ok, nil, "budget mutation refused")
eq(MclarionWowReputationData, stable, "budget mutation atomic")
eq(stable.characters[guid][1]:find("MHWOWR1", 1, true) ~= nil, true,
    "budget received only a copy")
MclarionWow_ReputationStorageBudget = function() return true end
rows[3].currentStanding = 1322
-- No valid snapshot may be silently replaced when a new owner exceeds the cap.
local full = {schema=1,settings={autoReputationCapture=false},characters={}}
for i = 1, 256 do
    local other = "Player-1234-X" .. i
    full.characters[other] = {wire:gsub(guid, other, 1)}
end
MclarionWowReputationData = full
ok = MclarionWow_CaptureReputation(true)
eq(ok, nil, "257th owner refused")
eq(MclarionWowReputationData, full, "owner limit preserves original")
MclarionWowReputationData = stable
-- A getter may reuse a single table and mutate it in place between passes.
local shared = clone(rows[3])
local calls = 0
C_Reputation.GetFactionDataByIndex = function(i)
    calls = calls + 1
    if i == 3 then
        shared.currentStanding = calls > 3 and 1400 or 1322
        return shared
    end
    return rows[i]
end
ok = MclarionWow_CaptureReputation(true)
eq(ok, nil, "reused mutable row changed between passes")
eq(MclarionWowReputationData, stable, "mutable row keeps old history")
C_Reputation.GetFactionDataByIndex = read
-- Empty is an observation of a visible UI view, not proof of zero reputation.
local oldCount = C_Reputation.GetNumFactions
C_Reputation.GetNumFactions = function() return 0 end
now = now + 1
ok, reason = MclarionWow_CaptureReputation(true)
eq(ok, true, "manual empty view can be recorded")
eq(reason, "saved", "empty view explicitly observed")
local emptyRecord = MclarionWowReputationData.characters[guid][20]
eq(emptyRecord:match("|visible%-ui|0|0|0|0|$") ~= nil, true,
    "empty record remains scoped visible-ui")
C_Reputation.GetNumFactions = oldCount
MclarionWowReputationData = nil
eq(MclarionWow_ReputationAutoEnabled(), false, "missing root reload off")
print("Reputation capture: " .. checks .. " assertions passed")
