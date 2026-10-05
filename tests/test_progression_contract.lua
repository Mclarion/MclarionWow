-- Test-only reference checks for a proposed schema-3 wire format. No game save input.
local contract = dofile("tests/progression_contract.lua")
local guid = "Player-1234-ABCDEF12" -- fixed synthetic identifier
local quest = "MHWOWQ1|forever|1720000000|" .. guid .. "|70205|active-log|12|2|42,84"
local parsed = assert(contract.parseQuest(quest, guid))
assert(parsed.rows == 12 and parsed.ids[1] == 42 and parsed.ids[2] == 84)
assert(contract.parseQuest(quest:gsub("|42,84$", "|84,42"), guid) == nil,
    "quest IDs must be strictly ascending")
local badQuestRecords = {
    quest:gsub("|12|2|", "|11|3|"), -- claimed count mismatches IDs
    quest:gsub("|12|2|", "|129|2|"), -- visible scan exceeds limit
    quest:gsub("|1720000000|", "|0|"),
    quest:gsub("|70205|", "|0|"),
    quest:gsub("|42,84$", "|42,42"),
    quest:gsub("|42,84$", "|042,84"),
    quest:gsub("|42,84$", "|42,2147483648"),
    (quest:gsub("Player%-1234%-ABCDEF12", "Player-other-unsafe")),
}
for index, bad in ipairs(badQuestRecords) do
    assert(contract.parseQuest(bad, guid) == nil, "bad quest wire accepted: " .. index)
end

local reputation = "MHWOWR1|forever|1720000001|" .. guid ..
    "|70205|visible-ui|9|2|0|0|100:4:0:3000:1200;200:5:3000:9000:4200"
local rep = assert(contract.parseReputation(reputation, guid))
assert(rep.rows == 9 and rep.headerRep == 0 and rep.collapsed == 0 and
    rep.entries[1].id == 100 and rep.entries[2].value == 4200)
assert(contract.parseReputation(reputation:gsub("100:4", "100:0"), guid) == nil,
    "reaction must be in the supported range")
assert(contract.parseReputation(reputation:gsub("1200;", "4000;"), guid) == nil,
    "standing value must remain within its interval")
assert(contract.parseReputation(reputation:gsub("100:4", "200:4"), guid) == nil,
    "faction IDs must be strictly ascending")
local observed = {
    { id = 200, isAccountWide = false },
    { id = 100, isAccountWide = false }, -- UI order need not be wire order
}
local function scoped(leaves, wire)
    return contract.characterReputationEligible(leaves, wire or reputation, guid)
end
assert(scoped(observed), "each verified character leaf matches the proposed R1 IDs")
local emptyWire = "MHWOWR1|forever|1720000003|" .. guid ..
    "|70205|visible-ui|0|0|0|0|"
assert(scoped({}, emptyWire), "empty visible leaf set is scoped")
assert(scoped({ observed[1], { id = 100, isAccountWide = true } }) == nil,
    "one account-wide leaf refuses the entire proposed R1 observation")
assert(scoped({ observed[1], { id = 100 } }) == nil,
    "unclassifiable provenance refuses the entire category")
assert(scoped({ [1] = observed[1], [3] = observed[2] }) == nil,
    "internally missing leaf index cannot be silently truncated")
assert(scoped({ [1] = observed[1], note = observed[2] }) == nil,
    "mixed numeric/string leaf keys are refused")
assert(scoped({ observed[1], observed[2], observed[1] }) == nil,
    "extra leaves beyond the record count are refused")
assert(scoped({ observed[1], { id = 300, isAccountWide = false } }) == nil,
    "provenance must bind to the actual wire faction IDs")
assert(scoped({ observed[1], observed[1] }) == nil,
    "duplicate observed faction IDs cannot fill two record entries")
local emptyQuest = "MHWOWQ1|forever|1720000002|" .. guid ..
    "|70205|active-log|0|0|"
local emptyReputation = "MHWOWR1|forever|1720000003|" .. guid ..
    "|70205|visible-ui|0|0|0|0|"
assert(contract.parseQuest(emptyQuest, guid) and
    contract.parseReputation(emptyReputation, guid),
    "canonical empty visible observations remain representable")
local badReputationRecords = {
    reputation:gsub("|9|2|0|0|", "|9|3|0|0|"),
    reputation:gsub("|9|2|0|0|", "|257|2|0|0|"),
    reputation:gsub("|9|2|0|0|", "|9|2|8|0|"),
    reputation:gsub("100:4:0:3000:1200", "100:4:3000:0:1200"),
    reputation:gsub("100:4:0:3000:1200", "100:4:00:3000:1200"),
    reputation:gsub("100:4:0:3000:1200", "100:4:0:3000"),
    reputation:gsub("100:4:0:3000:1200;200", "200:4:0:3000:1200;200"),
    (reputation:gsub("Player%-1234%-ABCDEF12", "Player-other-unsafe")),
}
for index, bad in ipairs(badReputationRecords) do
    assert(contract.parseReputation(bad, guid) == nil,
        "bad reputation wire accepted: " .. index)
end

local root = {
    schema = 3,
    settings = { autoQuestCapture = false, autoReputationCapture = false },
    characters = {}, items = {},
    progression = { [guid] = { quests = { quest }, reputation = { reputation } } },
}
assert(contract.validateRoot(root))
assert(contract.stateKey(quest) == contract.stateKey(quest:gsub("1720000000", "1720000010")),
    "quest state key ignores timestamp only")
assert(contract.stateKey(reputation) ==
    contract.stateKey(reputation:gsub("1720000001", "1720000011")),
    "reputation state key ignores timestamp only")
local duplicateState = {
    schema = 3,
    settings = root.settings,
    characters = {}, items = {},
    progression = { [guid] = { quests = { quest,
        quest:gsub("1720000000", "1720000010") }, reputation = { reputation } } },
}
assert(contract.validateRoot(duplicateState) == nil,
    "adjacent duplicate progression states must be deduplicated")
root.settings.autoQuestCapture = "false"
assert(contract.validateRoot(root) == nil, "progression opt-ins must be booleans")

local function loadFixture()
    local environment = {}
    local path = "tests/schema3-progression-synthetic.lua"
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
local fixtureEnv = { MclarionWowData = loadFixture() }
assert(contract.validateRoot(fixtureEnv.MclarionWowData),
    "fabricated schema-3 progression fixture must match the reference validator")
assert(fixtureEnv.MclarionWowData.settings.autoQuestCapture == false and
    fixtureEnv.MclarionWowData.settings.autoReputationCapture == false,
    "fabricated progression fixture keeps both new opt-ins off")
local tooLong = {}
for index = 1, 21 do
    tooLong[index] = quest:gsub("1720000000", tostring(1720000000 + index))
        :gsub("|42,84$", "|42," .. tostring(84 + index))
end
fixtureEnv.MclarionWowData.progression[guid].quests = tooLong
assert(contract.validateRoot(fixtureEnv.MclarionWowData) == nil,
    "progression history cannot exceed twenty observations")
local function fixtureRoot()
    return loadFixture()
end
local sparse = fixtureRoot()
sparse.progression[guid].quests = { [1] = quest, [3] = emptyQuest }
assert(contract.validateRoot(sparse) == nil, "sparse progression histories are rejected")
local backwards = fixtureRoot()
backwards.progression[guid].quests = { quest,
    quest:gsub("1720000000", "1719999999"):gsub("|42,84$", "|42,85") }
assert(contract.validateRoot(backwards) == nil,
    "progression timestamps must be strictly increasing")
local unknown = fixtureRoot()
unknown.progression[guid].achievements = { quest }
assert(contract.validateRoot(unknown) == nil, "unknown progression categories are rejected")
local unknownRoot = fixtureRoot()
unknownRoot.privatePayload = {}
assert(contract.validateRoot(unknownRoot) == nil, "unknown schema-3 root keys are rejected")
local unknownSetting = fixtureRoot()
unknownSetting.settings.autoPrivateCapture = false
assert(contract.validateRoot(unknownSetting) == nil, "unknown schema-3 settings are rejected")
local owners = fixtureRoot()
owners.progression = {}
for index = 1, 257 do
    local owner = "Player-TEST-" .. index
    local wire = "MHWOWQ1|forever|1720000000|" .. owner ..
        "|70205|active-log|1|1|" .. index
    owners.progression[owner] = { quests = { wire } }
end
assert(contract.validateRoot(owners) == nil, "progression owner count is bounded")
local largeEntries = {}
for index = 1, 200 do
    largeEntries[index] = index .. ":4:-2147483647:2147483647:0"
end
local oversized = {
    schema = 3,
    settings = { autoQuestCapture = false, autoReputationCapture = false },
    characters = {}, items = {},
    progression = {},
}
for ownerIndex = 1, 18 do
    local owner = "Player-BYTES-" .. ownerIndex
    local history = {}
    for historyIndex = 1, 20 do
        history[historyIndex] = "MHWOWR1|forever|" ..
            tostring(1720000000 + historyIndex) .. "|" .. owner .. "|" ..
            tostring(70205 + historyIndex) .. "|visible-ui|200|200|0|0|" ..
            table.concat(largeEntries, ";")
    end
    oversized.progression[owner] = { reputation = history }
end
assert(contract.validateRoot(oversized) == nil, "aggregate progression bytes are bounded")
print("progression contract: records, storage bounds and dedup accepted")
