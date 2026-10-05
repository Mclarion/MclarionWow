-- Test-only preflight for a proposed schema-3 root; never writes SavedVariables.
local preflight = dofile("tests/schema3_preflight.lua")
local contract = dofile("tests/progression_contract.lua")
local projection = dofile("tests/save_size_projection.lua")
local guid = "Player-1234-ABCDEF12" -- fabricated test owner

local function loadSynthetic(path)
    local environment = {}
    assert(loadfile(path, "t", environment))()
    return assert(environment.MclarionWowData)
end
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end
local function equal(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    for key, value in pairs(left) do
        if not equal(value, right[key]) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end
local extension = loadSynthetic("tests/schema3-progression-synthetic.lua").progression
for _, fixture in ipairs({ "tests/schema2-synthetic.lua", "tests/schema2-synthetic-explicit.lua" }) do
    local source = loadSynthetic(fixture)
    local original = copy(source)
    local observation = copy(extension)
    assert(#source.items[guid].bank == 2, "populated second bank page required")
    local candidate = assert(preflight.prepare(source, observation))
    assert(candidate.schema == 3 and contract.validateRoot(candidate))
    assert(projection.estimate(candidate), "candidate fits provisional size cap")
    for _, field in ipairs({ "characters", "bags", "bank", "items" }) do
        assert(equal(candidate[field], source[field]), "legacy payload changed: " .. field)
        assert(candidate[field] ~= source[field], "candidate must not alias legacy tree")
    end
    assert(candidate.items[guid].bank[2] == source.items[guid].bank[2],
        "candidate preserves the second bank metadata page exactly")
    assert(equal(source, original) and equal(observation, extension),
        "success must not modify source or observation")
    candidate.items[guid].bank[2] = nil
    assert(equal(source, original), "subsequent candidate changes cannot alter source")

    local belowSource = assert(projection.estimate(source))
    assert(preflight.prepare(source, observation, belowSource) == nil,
        "candidate exceeding a valid source-only budget must be rejected")
    assert(equal(source, original), "size rejection leaves populated schema-2 root untouched")
    local invalid = copy(observation)
    invalid[guid].quests[1] = "malformed"
    local invalidBefore = copy(invalid)
    assert(preflight.prepare(source, invalid) == nil,
        "invalid proposed progression record must be rejected")
    assert(equal(source, original) and equal(observation, extension) and
        equal(invalid, invalidBefore),
        "contract rejection leaves source and both observations untouched")
    local malformed = copy(source)
    malformed.items[guid].bank[2] = function() end
    local malformedOriginal = copy(malformed)
    assert(preflight.prepare(malformed, observation) == nil,
        "unsupported preserved value must fail before candidate construction")
    assert(equal(malformed, malformedOriginal), "source rejection cannot rewrite legacy histories")
    local cyclic = copy(observation)
    cyclic.self = cyclic
    assert(preflight.prepare(source, cyclic) == nil and cyclic.self == cyclic and
        equal(source, original), "cyclic observations are refused without mutation")
    local aliased = copy(observation)
    aliased[guid].reputation = aliased[guid].quests
    assert(preflight.prepare(source, aliased) == nil and
        aliased[guid].reputation == aliased[guid].quests and equal(source, original),
        "shared observation tables are refused without mutation")
end
local hostileRoot = setmetatable({}, { __index = function(root)
    rawset(root, "touched", true)
    return 2
end })
assert(preflight.prepare(hostileRoot, extension) == nil and
    rawget(hostileRoot, "touched") == nil,
    "root metatable must be refused before a field access can mutate it")
local hostileSettings = setmetatable({}, { __index = function(settings)
    rawset(settings, "touched", true)
    return false
end })
local settingsRoot = loadSynthetic("tests/schema2-synthetic.lua")
settingsRoot.settings = hostileSettings
assert(preflight.prepare(settingsRoot, extension) == nil and
    rawget(hostileSettings, "touched") == nil,
    "settings metatable must be refused before reading its flags")
print("test-only schema-3 preflight: populated roots and failure preservation accepted")
