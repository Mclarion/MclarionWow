-- Candidate active quest-log observations. Isolated SavedVariables root: the
-- schema-2 MclarionWowData tree is never migrated or changed by this module.
local MAX_ID = 2147483647
local PROTECTED = "Quest protected value refused."
local function protectionReady()
    if type(issecretvalue) ~= "function" or type(issecrettable) ~= "function" then return false end
    local valueOk, value = pcall(issecretvalue, nil)
    local tableOk, tableValue = pcall(issecrettable, {})
    return valueOk and type(value) == "boolean" and tableOk and type(tableValue) == "boolean"
end
local function secret(v)
    local ok, result = pcall(issecretvalue, v)
    if not ok or type(result) ~= "boolean" or result then return true end
    if type(v) == "table" then
        local tableOk, hidden = pcall(issecrettable, v)
        return not tableOk or type(hidden) ~= "boolean" or hidden
    end
    return false
end
local function plain(v)
    if secret(v) or type(v) ~= "table" then return false end
    local checked, hidden = pcall(issecrettable, v)
    if not checked or type(hidden) ~= "boolean" or hidden then return false end
    local ok, meta = pcall(getmetatable, v)
    return ok and not secret(meta) and meta == nil
end
local function integer(v, low, high)
    return type(v) == "number" and v >= low and v <= high and v == math.floor(v)
end
local function owner(v)
    return type(v) == "string" and #v >= 11 and #v <= 77 and
        v:match("^Player%-[A-Za-z0-9%-]+$") ~= nil
end
local function canonical(text, low, high)
    if type(text) ~= "string" or
        (text ~= "0" and not text:match("^[1-9]%d*$")) then return nil end
    local n = tonumber(text)
    if n and integer(n, low, high) and tostring(n) == text then return n end
end
local function parseRecord(record, guid)
    if secret(record) or type(record) ~= "string" or #record > 4096 then return end
    local fields = {}
    for part in (record .. "|"):gmatch("(.-)|") do fields[#fields + 1] = part end
    if #fields ~= 9 or fields[1] ~= "MHWOWQ1" or fields[2] ~= "forever" or
        fields[4] ~= guid or fields[6] ~= "active-log" then return end
    local stamp = canonical(fields[3], 1, 253402300799)
    local build = canonical(fields[5], 1, MAX_ID)
    local count = canonical(fields[7], 0, 128)
    local leaves = canonical(fields[8], 0, 100)
    if not stamp or not build or not count or not leaves or leaves > count then return end
    local previous, seen = 0, 0
    if fields[9] ~= "" then
        if fields[9]:sub(1, 1) == "," or fields[9]:sub(-1) == "," or
            fields[9]:find(",,", 1, true) then return end
        for idText in fields[9]:gmatch("[^,]+") do
            local id = canonical(idText, 1, MAX_ID)
            if not id or id <= previous then return end
            previous, seen = id, seen + 1
        end
    end
    if seen ~= leaves then return end
    -- State comparison deliberately ignores only capture time.
    return stamp, record:sub(1, #fields[1] + #fields[2] + 2) ..
        record:match("^MHWOWQ1|forever|[^|]+|(.*)$")
end
local function validate(root)
    if secret(root) then return nil, PROTECTED end
    if not plain(root) then return nil, "Quest storage unavailable." end
    for k in pairs(root) do
        if secret(k) then return nil, PROTECTED end
        if k ~= "schema" and k ~= "settings" and k ~= "characters" then
            return nil, "Quest storage format refused." end
    end
    local schema, settings, characters = rawget(root, "schema"),
        rawget(root, "settings"), rawget(root, "characters")
    if secret(schema) or secret(settings) or secret(characters) then
        return nil, PROTECTED end
    if schema ~= 1 or not plain(settings) or not plain(characters) or
        settings == characters or settings == root or characters == root then
        return nil, "Quest storage format refused." end
    for k, value in pairs(settings) do
        if secret(k) or secret(value) then return nil, PROTECTED end
        if k ~= "autoQuestCapture" or type(value) ~= "boolean" then
            return nil, "Quest setting format refused." end
    end
    local flag = rawget(settings, "autoQuestCapture")
    if secret(flag) then return nil, PROTECTED end
    if type(flag) ~= "boolean" then return nil, "Quest setting format refused." end
    local owners, bytes = 0, 0
    for guid, history in pairs(characters) do
        if secret(guid) or secret(history) then return nil, PROTECTED end
        if not owner(guid) or not plain(history) or
            history == settings or history == characters or history == root then
            return nil, "Quest history format refused." end
        owners = owners + 1
        if owners > 256 then return nil, "Quest owner limit reached." end
        local count, lastStamp, lastState = 0, 0, nil
        for key, record in pairs(history) do
            if secret(key) then return nil, PROTECTED end
            if not integer(key, 1, 20) then
                return nil, "Quest history format refused." end
            count = count + 1
        end
        if count == 0 or count > 20 then return nil, "Quest history format refused." end
        for i = 1, count do
            local record = rawget(history, i)
            local stamp, state = parseRecord(record, guid)
            if not stamp or stamp <= lastStamp or state == lastState then
                return nil, "Quest history format refused." end
            bytes = bytes + #record
            if bytes > 1048576 then return nil, "Quest storage limit reached." end
            lastStamp, lastState = stamp, state
        end
    end
    return characters, settings, bytes, owners
end
local function method(namespace, name)
    if not plain(namespace) then return nil end
    local ok, fn = pcall(function() return namespace[name] end)
    if not ok or secret(fn) or type(fn) ~= "function" then return nil end
    return fn
end
local function countRows(read)
    local ok, count = pcall(read)
    if not ok or secret(count) or not integer(count, 0, 128) then return nil end
    return count
end
local function scan()
    local namespace = C_QuestLog
    local count = method(namespace, "GetNumQuestLogEntries")
    local read = method(namespace, "GetInfo")
    if not count or not read then return nil, nil, "Quest API unavailable." end
    local rows, ids = {}, {}
    local rowCount
    for pass = 1, 2 do
        local n = countRows(count)
        if not n or (rowCount and rowCount ~= n) then return nil, nil, "Quest view changed or unavailable." end
        rowCount = n
        for i = 1, n do
            local ok, info = pcall(read, i)
            if not ok or not plain(info) then return nil, nil, "Quest row unavailable." end
            local fieldsOk, header, index = pcall(function()
                return info.isHeader, info.questLogIndex end)
            if not fieldsOk or secret(header) or secret(index) or
                type(header) ~= "boolean" or index ~= i then
                return nil, nil, "Quest row unavailable." end
            local signature
            if header then
                local titleOk, title = pcall(function() return info.title end)
                if not titleOk or secret(title) or type(title) ~= "string" or
                    #title < 1 or #title > 256 then return nil, nil, "Quest header unavailable." end
                signature = "H" .. #title .. ":" .. title
            else
                local idOk, id = pcall(function() return info.questID end)
                if not idOk or secret(id) or not integer(id, 1, MAX_ID) then
                    return nil, nil, "Quest ID unavailable." end
                signature = "Q" .. tostring(id)
                if pass == 1 then
                    if ids[id] then return nil, nil, "Duplicate quest ID." end
                    ids[id] = true
                end
            end
            if pass == 1 then rows[i] = signature
            elseif rows[i] ~= signature then return nil, nil, "Quest view changed." end
        end
        if countRows(count) ~= n then return nil, nil, "Quest view changed." end
    end
    local sorted = {}
    for id in pairs(ids) do sorted[#sorted + 1] = id end
    if #sorted > 100 then return nil, nil, "Quest leaf limit reached." end
    table.sort(sorted)
    for i, id in ipairs(sorted) do sorted[i] = tostring(id) end
    return rowCount, sorted
end
local function context()
    local combat = InCombatLockdown
    if secret(combat) or type(combat) ~= "function" then return nil, nil, nil, "Combat status unavailable." end
    local ok, locked = pcall(combat)
    if not ok or secret(locked) or type(locked) ~= "boolean" or locked then
        return nil, nil, nil, "Quest capture unavailable in combat." end
    local guidFn, timeFn, buildFn = UnitGUID, GetServerTime, GetBuildInfo
    if secret(guidFn) or secret(timeFn) or secret(buildFn) or
        type(guidFn) ~= "function" or type(timeFn) ~= "function" or
        type(buildFn) ~= "function" then return nil, nil, nil, "Quest metadata unavailable." end
    local own, guid = pcall(guidFn, "player")
    local timed, timestamp = pcall(timeFn)
    local built, _, buildText = pcall(buildFn)
    if not own or not timed or not built or secret(guid) or secret(timestamp) or
        secret(buildText) or not owner(guid) or not integer(timestamp, 1, 253402300799) or
        type(buildText) ~= "string" then return nil, nil, nil, "Quest metadata unavailable." end
    local build = canonical(buildText, 1, MAX_ID)
    if not build then return nil, nil, nil, "Quest metadata unavailable." end
    return guid, timestamp, build
end
local function candidateRoot(root)
    if secret(root) then return nil, PROTECTED end
    if root == nil then
        return { schema = 1, settings = { autoQuestCapture = false }, characters = {} }, nil, 0
    end
    local characters, settings, _, owners = validate(root)
    if not characters then return nil, settings end
    -- Copy only validated, bounded data; never mutate an existing root in place.
    local copy = { schema = 1, settings = { autoQuestCapture = settings.autoQuestCapture }, characters = {} }
    for guid, history in pairs(characters) do
        local entries = {}
        for i = 1, #history do entries[i] = history[i] end
        copy.characters[guid] = entries
    end
    return copy, nil, owners
end
local function budget(candidate)
    local fn = MclarionWow_QuestStorageBudget
    if secret(fn) then return nil, PROTECTED end
    if type(fn) ~= "function" then return nil, "Quest storage budget refused." end
    local ok, allowed = pcall(fn, candidate)
    if not ok then return nil, "Quest storage budget refused." end
    if secret(allowed) then return nil, PROTECTED end
    if allowed ~= true then return nil, "Quest storage budget refused." end
    return true
end
function MclarionWow_QuestAutoEnabled()
    if not protectionReady() then return false, PROTECTED end
    local root = MclarionWowQuestData
    if secret(root) then return false, PROTECTED end
    if root == nil then return false end
    local characters, settings = validate(root)
    if not characters then return false, settings end
    return settings.autoQuestCapture == true
end
function MclarionWow_SetAutoQuestCapture(enabled)
    if not protectionReady() then return nil, PROTECTED end
    if secret(enabled) then return nil, PROTECTED end
    if type(enabled) ~= "boolean" then return nil, "Quest setting unavailable." end
    local root, err = candidateRoot(MclarionWowQuestData)
    if not root then return nil, err end
    if root.settings.autoQuestCapture == enabled then return true end
    root.settings.autoQuestCapture = enabled
    local allowed, budgetError = budget(root)
    if not allowed then return nil, budgetError end
    MclarionWowQuestData = root
    return true
end
function MclarionWow_CaptureQuests(manual)
    if not protectionReady() then return nil, PROTECTED end
    if secret(manual) or secret(MclarionWowQuestData) then return nil, PROTECTED end
    local guid, timestamp, build, err = context()
    if not guid then return nil, err end
    local source = MclarionWowQuestData
    local root, reason, owners = candidateRoot(source)
    if not root then return nil, reason end
    if not manual and not root.settings.autoQuestCapture then return nil, "Automatic quest capture is off." end
    local rowCount, ids, scanError = scan()
    if not rowCount then return nil, scanError end
    -- A transient empty log is never taken as proof that a previous active
    -- set was completed. Explicit manual capture may confirm it.
    local previous = root.characters[guid]
    if not manual and #ids == 0 and previous and #previous > 0 then
        return nil, "Empty quest log needs manual confirmation." end
    local wire = table.concat({ "MHWOWQ1", "forever", tostring(timestamp), guid,
        tostring(build), "active-log", tostring(rowCount), tostring(#ids),
        table.concat(ids, ",") }, "|")
    if #wire > 4096 then return nil, "Quest record limit reached." end
    local stamp, state = parseRecord(wire, guid)
    if not stamp then return nil, "Quest record unavailable." end
    if previous then
        local priorStamp, priorState = parseRecord(previous[#previous], guid)
        if not priorStamp then return nil, "Quest history format refused." end
        if state == priorState then return true, "unchanged" end
        if timestamp <= priorStamp then return true, "same-second" end
    elseif owners >= 256 then return nil, "Quest owner limit reached." end
    local stillGuid, _, _, checkError = context()
    if not stillGuid or stillGuid ~= guid then return nil, checkError or "Quest owner changed." end
    local history = previous or {}
    history[#history + 1] = wire
    if #history > 20 then table.remove(history, 1) end
    root.characters[guid] = history
    local valid, validationError = validate(root)
    if not valid then return nil, validationError end
    local allowed, budgetError = budget(root)
    if not allowed then return nil, budgetError end
    MclarionWowQuestData = root
    return true, "saved"
end
