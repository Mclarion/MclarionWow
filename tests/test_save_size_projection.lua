-- Synthetic-only preflight experiment; never load a live SavedVariables file.
local projection = dofile("tests/save_size_projection.lua")
local contract = dofile("tests/progression_contract.lua")
local guid = "Player-1234-ABCDEF12"

local function loadFixture(path)
    local file = assert(io.open(path, "rb"))
    local text = assert(file:read("*a"))
    assert(file:close())
    local env = {}
    local chunk
    if setfenv then
        chunk = assert(loadfile(path))
        setfenv(chunk, env)
    else
        chunk = assert(loadfile(path, "t", env))
    end
    chunk()
    return assert(env.MclarionWowData), #text
end

for _, path in ipairs({ "tests/schema2-synthetic.lua", "tests/schema2-synthetic-explicit.lua" }) do
    local legacy, actualBytes = loadFixture(path)
    local bound, reason = projection.estimate(legacy)
    assert(bound and not reason and bound >= actualBytes and bound < 3000000,
        "populated legacy fixture projection must exceed its serialized bytes")
    local extension = loadFixture("tests/schema3-progression-synthetic.lua")
    local proposed = {
        schema = 3,
        settings = legacy.settings,
        characters = legacy.characters,
        bags = legacy.bags,
        bank = legacy.bank,
        items = legacy.items,
        progression = extension.progression,
    }
    proposed.settings.autoQuestCapture = false
    proposed.settings.autoReputationCapture = false
    assert(contract.validateRoot(proposed), "synthetic proposed root must remain valid")
    assert(projection.estimate(proposed), "populated proposal fits provisional envelope")
end

local oversized = { schema = 3, characters = { [guid] = { string.rep("\0", 800000) } } }
assert(projection.estimate(oversized) == nil,
    "4-byte escaped payloads beyond provisional envelope must fail closed")
local cyclic = {}; cyclic.self = cyclic
assert(projection.estimate(cyclic) == nil, "cyclic tables must fail closed")
local unsupported = { [function() end] = "value" }
assert(projection.estimate(unsupported) == nil, "unsupported keys must fail closed")
assert(projection.estimate({ payload = function() end }) == nil,
    "unsupported values must fail closed")
local shortKey = assert(projection.estimate({ a = true }))
local escapedKey = assert(projection.estimate({ [string.rep("\0", 81)] = true }))
assert(escapedKey - shortKey >= 4 * 80,
    "escaped keys must be charged per byte, not only per table entry")
assert(projection.estimate({ [string.rep("\0", 81)] = true }, escapedKey) == escapedKey and
    projection.estimate({ [string.rep("\0", 81)] = true }, escapedKey - 1) == nil,
    "escaped-key root must respect the exact structural boundary")
local flat, nested = {}, {}
for index = 1, 200 do
    flat[index] = false
    nested[index] = { value = false }
end
local nestedBound = assert(projection.estimate(nested))
assert(nestedBound - assert(projection.estimate(flat)) >= 200 * 128,
    "table-heavy roots must charge structural overhead")
assert(projection.estimate(nested, nestedBound) == nestedBound and
    projection.estimate(nested, nestedBound - 1) == nil,
    "table-heavy roots must respect the exact structural boundary")
local base = assert(projection.estimate({ payload = "" }))
local nearLength = math.floor((3000000 - base) / 4)
local near = assert(projection.estimate({ payload = string.rep("\0", nearLength) }))
assert(near <= 3000000 and 3000000 - near < 4,
    "escaped value must fit immediately below the provisional boundary")
assert(projection.estimate({ payload = string.rep("\0", nearLength + 1) }) == nil,
    "one additional escaped byte must exceed the provisional boundary")
assert(projection.estimate({ payload = string.rep("\0", 80) }, escapedKey) == nil,
    "custom limit cannot bypass charged keys and values")
print("synthetic whole-root size projection: two legacy encodings and fail-closed edges")
