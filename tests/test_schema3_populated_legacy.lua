-- Test-only compatibility scaffold: no runtime migration or game save input.
local contract = dofile("tests/progression_contract.lua")
local guid = "Player-1234-ABCDEF12" -- synthetic fixture owner

local function loadSynthetic(path)
    local environment = {}
    local chunk
    if setfenv then
        chunk = assert(loadfile(path))
        setfenv(chunk, environment)
    else
        chunk = assert(loadfile(path, "t", environment))
    end
    chunk()
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

local progression = assert(loadSynthetic("tests/schema3-progression-synthetic.lua").progression[guid])
local originals = {}
local paths = {
    "tests/schema2-synthetic.lua", -- game-style implicit bank page indices
    "tests/schema2-synthetic-explicit.lua", -- explicit numeric bank page keys
}
local legacyFields = { "characters", "bags", "bank", "items" }
for index, path in ipairs(paths) do
    local source = loadSynthetic(path)
    assert(source.schema == 2 and source.items[guid] and
        #source.items[guid].bank == 2 and source.characters[guid] and
        source.bags[guid] and source.bank[guid], "populated legacy fixture required")
    local proposed = copy(source)
    proposed.schema = 3
    proposed.settings.autoQuestCapture = false
    proposed.settings.autoReputationCapture = false
    proposed.progression = { [guid] = copy(progression) }
    assert(contract.validateRoot(proposed), "populated schema-2 payload must coexist with progression")
    for _, field in ipairs(legacyFields) do
        assert(equal(source[field], proposed[field]), "legacy payload changed: " .. field)
    end
    assert(equal(source, loadSynthetic(path)), "source fixture changed")
    originals[index] = copy(proposed)

    -- Prove a dropped second bank metadata page trips the preservation check.
    proposed.items[guid].bank[2] = nil
    assert(not equal(source.items, proposed.items), "lost bank page must be detected")
end
for _, field in ipairs(legacyFields) do
    assert(equal(originals[1][field], originals[2][field]),
        "implicit and explicit bank arrays must have identical legacy payloads")
end
print("populated legacy fixture scaffold: both bank array encodings preserved")
