-- Synthetic-only migration guard: reject damaged legacy roots before cloning.
local shape = dofile("tests/schema2_legacy_shape.lua")
local preflight = dofile("tests/schema3_preflight.lua")
local owner = "Player-1234-ABCDEF12"

local function fixture(path)
    local scope = {}
    local chunk
    if setfenv then
        chunk = assert(loadfile(path))
        setfenv(chunk, scope)
    else
        chunk = assert(loadfile(path, "t", scope))
    end
    chunk()
    return assert(scope.MclarionWowData)
end

local function clone(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = clone(child) end
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

local observations = fixture("tests/schema3-progression-synthetic.lua").progression
for _, path in ipairs({ "tests/schema2-synthetic.lua", "tests/schema2-synthetic-explicit.lua" }) do
    local source = fixture(path)
    assert(shape.validate(source), "populated legacy fixture must be structurally accepted")
    assert(preflight.prepare(source, observations), "valid source must compose")
    local older = clone(source)
    older.characters[owner][1] = older.characters[owner][1]:gsub("^MHWOW2|", "MHWOW1|"):
        gsub("|Alliance|Dwarf|Male$", "")
    assert(shape.validate(older) and preflight.prepare(older, observations),
        "legacy gear-only MHWOW1 must remain accepted")
    local function refuse(mutator, label)
        local damaged = clone(source)
        mutator(damaged)
        local before = clone(damaged)
        assert(not shape.validate(damaged), label .. " must be refused by shape guard")
        assert(not preflight.prepare(damaged, observations), label .. " must refuse migration")
        assert(equal(damaged, before), label .. " must leave the source unchanged")
    end
    refuse(function(root) root.characters[owner][2] = root.characters[owner][1]:gsub("Player%-1234%-ABCDEF12", "Player-9999-ABCDEF12") end,
        "foreign character owner")
    refuse(function(root) root.bags[owner][1] = root.bags[owner][1]:gsub("MHWOWB1", "MHWOWK1") end,
        "swapped bag wire")
    refuse(function(root) root.bank[owner][1] = root.bank[owner][1]:gsub("|forever|", "|other|", 1) end,
        "foreign bank product")
    refuse(function(root) root.items[owner].bags = root.items[owner].bags:gsub("Player%-1234%-ABCDEF12", "Player-9999-ABCDEF12") end,
        "foreign item owner")
    refuse(function(root) root.items[owner].bank[3] = root.items[owner].bank[2]; root.items[owner].bank[2] = nil end,
        "sparse bank pages")
    refuse(function(root) root.items[owner].bank[2] = root.items[owner].bank[2] .. "|extra" end,
        "extra item wire field")
    refuse(function(root) root.bags[owner][1] = root.bags[owner][1]:gsub("4242:3", "4242:not-a-count") end,
        "invalid bag quantity")
    refuse(function(root) root.bank[owner][1] = root.bank[owner][1]:gsub("6:1:1", "15:1:1", 1) end,
        "account-bank tab")
    refuse(function(root) root.items[owner].bags = root.items[owner].bags:gsub("|1002:", "|invalid:", 1) end,
        "invalid item metadata ID")
    refuse(function(root) root.characters[owner].extra = root.characters[owner][1] end,
        "non-array history key")
    refuse(function(root) root.items[owner].unknown = true end,
        "unknown item category")
    refuse(function(root) root.items[owner] = {} end,
        "empty item owner")
    refuse(function(root) root.items[owner] = { bank = {} } end,
        "empty item bank pages")
    refuse(function(root) root.characters["not-a-player"] = root.characters[owner]; root.characters[owner] = nil end,
        "invalid owner key")
end
print("synthetic schema-2 shape guard: both bank array forms and fourteen refusals accepted")
