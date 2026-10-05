-- Test-only reference parser for a proposed progression wire contract.
-- This does not parse SavedVariables files and is not an addon writer/importer.
local Contract = {}

local function split(text, delimiter)
    local fields = {}
    local start = 1
    while true do
        local at = text:find(delimiter, start, true)
        if not at then
            fields[#fields + 1] = text:sub(start)
            return fields
        end
        fields[#fields + 1] = text:sub(start, at - 1)
        start = at + #delimiter
    end
end

local function unsigned(text, minimum, maximum)
    if type(text) ~= "string" or
        (text ~= "0" and not text:match("^[1-9]%d*$")) then return nil end
    local value = tonumber(text)
    if not value or value < minimum or value > maximum or
        value ~= math.floor(value) then return nil end
    return value
end

local function validGuid(value)
    return type(value) == "string" and #value <= 77 and
        value:match("^Player%-[A-Za-z0-9%-]+$") ~= nil
end

local function signed(text)
    if type(text) ~= "string" or not text:match("^%-?%d+$") or
        text == "-0" or text:match("^0%d") or text:match("^%-0%d") then return nil end
    local value = tonumber(text)
    if not value or value < -2147483647 or value > 2147483647 or
        value ~= math.floor(value) then return nil end
    return value
end

function Contract.parseQuest(text, guid)
    if type(text) ~= "string" or #text > 4096 or
        not validGuid(guid) then return nil, "invalid input" end
    local fields = split(text, "|")
    if #fields ~= 9 or fields[1] ~= "MHWOWQ1" or fields[2] ~= "forever" or
        fields[4] ~= guid or fields[6] ~= "active-log" then
        return nil, "invalid quest record"
    end
    local stamp = unsigned(fields[3], 1, 253402300799)
    local build = unsigned(fields[5], 1, 2147483647)
    local rows = unsigned(fields[7], 0, 128)
    local leafCount = unsigned(fields[8], 0, 100)
    if not stamp or not build or not rows or not leafCount or
        leafCount > rows then return nil, "invalid quest header" end
    local ids = {}
    local previous = 0
    if fields[9] ~= "" then
        for _, rawId in ipairs(split(fields[9], ",")) do
            local id = unsigned(rawId, 1, 2147483647)
            if not id or id <= previous or #ids >= 100 then
                return nil, "quest IDs invalid or not ascending"
            end
            ids[#ids + 1] = id
            previous = id
        end
    end
    if #ids ~= leafCount then return nil, "quest count mismatch" end
    return { rows = rows, ids = ids, timestamp = stamp, build = build, guid = guid }
end

function Contract.parseReputation(text, guid)
    if type(text) ~= "string" or #text > 32768 or
        not validGuid(guid) then return nil, "invalid input" end
    local fields = split(text, "|")
    if #fields ~= 11 or fields[1] ~= "MHWOWR1" or fields[2] ~= "forever" or
        fields[4] ~= guid or fields[6] ~= "visible-ui" then
        return nil, "invalid reputation record"
    end
    local stamp = unsigned(fields[3], 1, 253402300799)
    local build = unsigned(fields[5], 1, 2147483647)
    local rows = unsigned(fields[7], 0, 256)
    local leafCount = unsigned(fields[8], 0, 200)
    local headerRep = unsigned(fields[9], 0, 256)
    local collapsed = unsigned(fields[10], 0, 256)
    if not stamp or not build or not rows or not leafCount or not headerRep or
        not collapsed or leafCount > rows or leafCount + headerRep > rows or
        leafCount + collapsed > rows then return nil, "invalid reputation header" end
    local entries, previous = {}, 0
    if fields[11] ~= "" then
        for _, rawEntry in ipairs(split(fields[11], ";")) do
            local parts = split(rawEntry, ":")
            if #parts ~= 5 then return nil, "invalid reputation entry" end
            local id = unsigned(parts[1], 1, 2147483647)
            local reaction = unsigned(parts[2], 1, 16)
            local minimum, maximum, value = signed(parts[3]), signed(parts[4]),
                signed(parts[5])
            if not id or id <= previous or not reaction or not minimum or not maximum or
                not value or minimum >= maximum or value < minimum or value > maximum or
                #entries >= 200 then return nil, "invalid reputation entry" end
            entries[#entries + 1] = { id = id, reaction = reaction, minimum = minimum,
                maximum = maximum, value = value }
            previous = id
        end
    end
    if #entries ~= leafCount then return nil, "reputation count mismatch" end
    return { rows = rows, entries = entries, headerRep = headerRep,
        collapsed = collapsed, timestamp = stamp, build = build, guid = guid }
end

function Contract.stateKey(text)
    if type(text) ~= "string" then return nil end
    local fields = split(text, "|")
    if (fields[1] ~= "MHWOWQ1" and fields[1] ~= "MHWOWR1") or #fields < 4 then
        return nil
    end
    table.remove(fields, 3)
    return table.concat(fields, "|")
end

local function validateHistory(history, guid, kind)
    if type(history) ~= "table" then return nil end
    local count, bytes, previousState, previousStamp = 0, 0, nil, 0
    for index, text in ipairs(history) do
        count = count + 1
        if index ~= count or count > 20 or type(text) ~= "string" then return nil end
        local parsed = kind == "quests" and Contract.parseQuest(text, guid) or
            Contract.parseReputation(text, guid)
        local state = Contract.stateKey(text)
        if not parsed or not state or state == previousState or
            parsed.timestamp <= previousStamp then return nil end
        bytes = bytes + #text
        previousState, previousStamp = state, parsed.timestamp
    end
    if count == 0 or count ~= #history then return nil end
    for key in pairs(history) do
        if type(key) ~= "number" or key < 1 or key > count or
            key ~= math.floor(key) then return nil end
    end
    return bytes
end

function Contract.validateRoot(root)
    if type(root) ~= "table" or root.schema ~= 3 or type(root.settings) ~= "table" or
        type(root.settings.autoQuestCapture) ~= "boolean" or
        type(root.settings.autoReputationCapture) ~= "boolean" or
        type(root.characters) ~= "table" or type(root.items) ~= "table" or
        type(root.progression) ~= "table" then return nil, "invalid schema-3 root" end
    local allowedRoot = { schema = true, settings = true, characters = true,
        bags = true, bank = true, items = true, progression = true }
    for key in pairs(root) do
        if not allowedRoot[key] then return nil, "unsupported schema-3 root key" end
    end
    if root.bags ~= nil and type(root.bags) ~= "table" or
        root.bank ~= nil and type(root.bank) ~= "table" then
        return nil, "invalid legacy root shape"
    end
    local allowedSetting = { autoCombatLog = true, autoCharacterCapture = true,
        autoBagCapture = true, autoBankCapture = true,
        autoItemMetadataCapture = true, autoQuestCapture = true,
        autoReputationCapture = true }
    for key, value in pairs(root.settings) do
        if not allowedSetting[key] or type(value) ~= "boolean" then
            return nil, "invalid schema-3 setting"
        end
    end
    local owners, bytes = 0, 0
    for guid, record in pairs(root.progression) do
        if not validGuid(guid) or type(record) ~= "table" then
            return nil, "invalid progression owner"
        end
        owners = owners + 1
        if owners > 256 then return nil, "progression owner limit" end
        local fields = 0
        for kind, history in pairs(record) do
            if kind ~= "quests" and kind ~= "reputation" then
                return nil, "unsupported progression category"
            end
            fields = fields + 1
            local historyBytes = validateHistory(history, guid, kind)
            if not historyBytes then return nil, "invalid progression history" end
            bytes = bytes + historyBytes
            if bytes > 2097152 then return nil, "progression byte limit" end
        end
        if fields == 0 then return nil, "empty progression owner" end
    end
    return true
end

return Contract
