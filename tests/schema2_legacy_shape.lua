-- Synthetic-only structural gate for preserved schema-2 payloads. This checks
-- ownership, wire envelopes, numeric inventory rows, and array shape; it is
-- NOT a complete schema-2 importer or validator for names/metadata fields.
local Shape = {}

local function split(text, separator)
    local fields, start = {}, 1
    while true do
        local at = text:find(separator, start, true)
        if not at then
            fields[#fields + 1] = text:sub(start)
            return fields
        end
        fields[#fields + 1] = text:sub(start, at - 1)
        start = at + #separator
    end
end

local function integer(text, maximum)
    if type(text) ~= "string" or not text:match("^[1-9]%d*$") then return false end
    local number = tonumber(text)
    return number ~= nil and number <= maximum and number == math.floor(number)
end

local function ownerKey(owner)
    return type(owner) == "string" and #owner <= 77 and
        owner:match("^Player%-[A-Za-z0-9%-]+$") ~= nil
end

local function inventoryRows(text, bank)
    if text == "" then return true end
    local previousTab, previousId, count = 0, 0, 0
    for _, row in ipairs(split(text, ",")) do
        count = count + 1
        if count > (bank and 1080 or 1024) then return false end
        local parts = split(row, ":")
        if #parts ~= (bank and 3 or 2) then return false end
        local tab = bank and tonumber(parts[1]) or 0
        local item = bank and parts[2] or parts[1]
        local quantity = bank and parts[3] or parts[2]
        if (bank and (not integer(parts[1], 14) or tab < 6)) or
            not integer(item, 2147483647) or
            not integer(quantity, 2147483647) then return false end
        local id = tonumber(item)
        if tab < previousTab or (tab == previousTab and id <= previousId) then
            return false
        end
        previousTab, previousId = tab, id
    end
    return true
end

local function itemRows(text)
    local previousId, count = 0, 0
    for _, row in ipairs(split(text, ";")) do
        count = count + 1
        if count > 128 then return false end
        local parts = split(row, ":")
        if #parts ~= 19 or not integer(parts[1], 2147483647) or
            tonumber(parts[1]) <= previousId then return false end
        previousId = tonumber(parts[1])
    end
    return true
end

local function wire(text, owner, category)
    if type(text) ~= "string" or #text > (category == "bags" and 16000 or
        category == "characters" and 4096 or 32768) then return false end
    local fields = split(text, "|")
    local version = fields[1]
    local count = #fields
    if category == "characters" then
        if not ((version == "MHWOW1" and count == 12) or
            (version == "MHWOW2" and count == 15)) then return false end
    elseif category == "bags" or category == "bank" then
        if version ~= (category == "bags" and "MHWOWB1" or "MHWOWK1") or
            count ~= 6 or not inventoryRows(fields[5], category == "bank") then
            return false
        end
    elseif category == "items" then
        if version ~= "MHWOWI1" or count ~= 7 or
            not fields[6]:match("^[a-z][a-z][A-Z][A-Z]$") or
            fields[7] == "" or not itemRows(fields[7]) then return false end
    else
        return false
    end
    local build = category == "items" and fields[5] or
        category == "characters" and fields[12] or fields[6]
    return fields[2] == "forever" and fields[4] == owner and
        integer(fields[3], 253402300799) and integer(build, 2147483647)
end

local function array(value, maximum, checker)
    if type(value) ~= "table" or getmetatable(value) ~= nil then return false end
    local count = 0
    for key, child in pairs(value) do
        if type(key) ~= "number" or key ~= math.floor(key) or key < 1 or
            key > maximum or not checker(child) then return false end
        count = count + 1
    end
    if count ~= #value then return false end
    for index = 1, count do
        if rawget(value, index) == nil then return false end
    end
    return true
end

local function historyMap(map, category)
    if type(map) ~= "table" or getmetatable(map) ~= nil then return false end
    for owner, history in pairs(map) do
        if not ownerKey(owner) or not array(history, 20, function(text)
            return wire(text, owner, category)
        end) then return false end
    end
    return true
end

local allowedRoot = { schema = true, settings = true, characters = true,
    bags = true, bank = true, items = true }
local allowedSettings = { autoCombatLog = true, autoCharacterCapture = true,
    autoBagCapture = true, autoBankCapture = true, autoItemMetadataCapture = true }

function Shape.validate(root)
    if type(root) ~= "table" or getmetatable(root) ~= nil or
        rawget(root, "schema") ~= 2 or
        not historyMap(rawget(root, "characters"), "characters") then
        return nil, "invalid legacy shape"
    end
    for key in pairs(root) do
        if not allowedRoot[key] then return nil, "invalid legacy shape" end
    end
    local settings = rawget(root, "settings")
    if settings ~= nil then
        if type(settings) ~= "table" or getmetatable(settings) ~= nil then
            return nil, "invalid legacy shape"
        end
        for key, value in pairs(settings) do
            if not allowedSettings[key] or type(value) ~= "boolean" then
                return nil, "invalid legacy shape"
            end
        end
    end
    for _, category in ipairs({ "bags", "bank" }) do
        local map = rawget(root, category)
        if map ~= nil and not historyMap(map, category) then
            return nil, "invalid legacy shape"
        end
    end
    local items = rawget(root, "items")
    if type(items) ~= "table" or getmetatable(items) ~= nil then
        return nil, "invalid legacy shape"
    end
    for owner, record in pairs(items) do
        if not ownerKey(owner) or type(record) ~= "table" or
            getmetatable(record) ~= nil then return nil, "invalid legacy shape" end
        local fields = 0
        for key in pairs(record) do
            if key ~= "bags" and key ~= "bank" then
                return nil, "invalid legacy shape"
            end
            fields = fields + 1
        end
        if fields == 0 then return nil, "invalid legacy shape" end
        if record.bags ~= nil and not wire(record.bags, owner, "items") then
            return nil, "invalid legacy shape"
        end
        if record.bank ~= nil and not array(record.bank, 9, function(text)
            return wire(text, owner, "items")
        end) then return nil, "invalid legacy shape" end
        if record.bank ~= nil and #record.bank == 0 then
            return nil, "invalid legacy shape"
        end
    end
    return true
end

return Shape
