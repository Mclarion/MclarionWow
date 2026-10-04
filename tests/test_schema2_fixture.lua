-- Run against a generated, synthetic fixture; never a real player save.
local fixture = assert(..., "usage: lua tests/test_schema2_fixture.lua <fixture>")
local file = assert(io.open(fixture, "rb"))
local serialized = assert(file:read("*a"))
assert(file:close())
assert(serialized:match('%["bank"%]%s*=%s*{%s*"MHWOWI1|forever|'),
    "bank pages must use the game's implicit Lua array syntax")
assert(loadfile(fixture))()
local data = assert(MclarionWowData)
assert(data.schema == 2)
local guid = "Player-1234-ABCDEF12"
local record = assert(data.items[guid])
assert(type(record.bags) == "string")
assert(type(record.bank) == "table" and #record.bank == 2,
    "reader fixture must include two own-bank metadata pages")
assert(record.bank[1]:match("^MHWOWI1|forever|") and
    record.bank[2]:match("^MHWOWI1|forever|"))
assert(record.bank[1]:find("|129:", 1, true) == nil and
    record.bank[2]:find("|129:", 1, true) ~= nil,
    "the second page must carry the item beyond page one's 128 IDs")
assert(type(data.characters[guid][1]) == "string" and
    type(data.bags[guid][1]) == "string" and
    type(data.bank[guid][1]) == "string")
print("schema-2 synthetic two-page fixture verified")
