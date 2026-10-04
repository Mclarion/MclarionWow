-- Compare builder-generated synthetic saves; never use real player data.
local implicitPath, explicitPath = ...
assert(implicitPath and explicitPath,
    "usage: lua tests/test_schema2_fixture_pair.lua <implicit> <explicit>")

local function read(path)
    local file = assert(io.open(path, "rb"))
    local text = assert(file:read("*a"))
    assert(file:close())
    return text
end

local implicitText, explicitText = read(implicitPath), read(explicitPath)
assert(implicitText:match('%["bank"%]%s*=%s*{%s*"MHWOWI1|forever|'),
    "first fixture must use the game's implicit bank-page array")
assert(explicitText:match('%["bank"%]%s*=%s*{%s*%[1%]%s*=%s*"MHWOWI1|forever|'),
    "second fixture must use explicit numeric bank-page keys")
assert(implicitText ~= explicitText, "fixtures must differ in serialization")

local function loadSynthetic(path)
    MclarionWowData = nil
    assert(loadfile(path))()
    return assert(MclarionWowData)
end
local implicit, explicit = loadSynthetic(implicitPath), loadSynthetic(explicitPath)

local function equivalent(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do
        if not equivalent(value, b[key]) then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end
assert(equivalent(implicit, explicit),
    "both Lua spellings must decode to identical saved categories and pages")
assert(implicit.schema == 2)
local record = assert(implicit.items["Player-1234-ABCDEF12"])
assert(type(record.bank) == "table" and #record.bank == 2)
print("schema-2 implicit and explicit fixtures are semantically equal")
