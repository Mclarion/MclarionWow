-- Offline candidate only: character-scoped visible faction observations.
-- Not loaded by the TOC. This root never modifies schema-2 MclarionWowData.
local MAX_ID, MAX_VALUE = 2147483647, 2147483647
local function primitives()
    return type(issecretvalue) == "function" and type(issecrettable) == "function"
end
local function secret(v) return issecretvalue(v) end
local function plain(v)
    if secret(v) or type(v) ~= "table" or issecrettable(v) then return false end
    local ok, meta = pcall(getmetatable, v)
    return ok and not secret(meta) and meta == nil
end
local function integer(v, lo, hi)
    return not secret(v) and type(v) == "number" and v >= lo and
        v <= hi and v == math.floor(v)
end
local function guid(v)
    return not secret(v) and type(v) == "string" and #v >= 8 and #v <= 77 and
        v:match("^Player%-[A-Za-z0-9%-]+$") ~= nil
end
local function unsigned(text, lo, hi)
    if type(text) ~= "string" or
        (text ~= "0" and not text:match("^[1-9]%d*$")) then return nil end
    local v = tonumber(text)
    if integer(v, lo, hi) and tostring(v) == text then return v end
end
local function signed(text)
    if type(text) ~= "string" or not text:match("^%-?%d+$") or
        text == "-0" or text:match("^0%d") or text:match("^%-0%d") then return nil end
    local v = tonumber(text)
    if integer(v, -MAX_VALUE, MAX_VALUE) and tostring(v) == text then return v end
end
local function split(text, delimiter)
    local out, start = {}, 1
    while true do
        local pos = text:find(delimiter, start, true)
        if not pos then out[#out + 1] = text:sub(start); return out end
        out[#out + 1] = text:sub(start, pos - 1)
        start = pos + #delimiter
    end
end
local function parseRecord(record, owner)
    if secret(record) or type(record) ~= "string" or #record > 32768 then return end
    local f = split(record, "|")
    if #f ~= 11 or f[1] ~= "MHWOWR1" or f[2] ~= "forever" or
        f[4] ~= owner or f[6] ~= "visible-ui" then return end
    local stamp, build = unsigned(f[3], 1, 253402300799), unsigned(f[5], 1, MAX_ID)
    local rows, leaves = unsigned(f[7], 0, 256), unsigned(f[8], 0, 200)
    local headerRep, collapsed = unsigned(f[9], 0, 256), unsigned(f[10], 0, 256)
    if not stamp or not build or not rows or not leaves or not headerRep or
        not collapsed or leaves > rows or leaves + headerRep > rows or
        leaves + collapsed > rows then return end
    local seen, previous = 0, 0
    if f[11] ~= "" then
        for _, entry in ipairs(split(f[11], ";")) do
            local fields = split(entry, ":")
            if #fields ~= 5 then return end
            local id, reaction = unsigned(fields[1], 1, MAX_ID),
                unsigned(fields[2], 1, 16)
            local min, max, value = signed(fields[3]), signed(fields[4]), signed(fields[5])
            if not id or id <= previous or not reaction or not min or not max or
                not value or min >= max or value < min or value > max then return end
            seen, previous = seen + 1, id
            if seen > 200 then return end
        end
    end
    if seen ~= leaves then return end
    -- Ignore capture time, not scope, row counts, or standing values.
    return stamp, "MHWOWR1|forever|" .. record:match("^MHWOWR1|forever|[^|]+|(.*)$")
end
local function validate(root)
    if not plain(root) then return nil, "Reputation storage unavailable." end
    for key in pairs(root) do
        if secret(key) or (key ~= "schema" and key ~= "settings" and key ~= "characters") then
            return nil, "Reputation storage format refused." end
    end
    local schema, settings, characters = rawget(root, "schema"),
        rawget(root, "settings"), rawget(root, "characters")
    if secret(schema) or not plain(settings) or not plain(characters) or
        schema ~= 1 or root == settings or root == characters or settings == characters then
        return nil, "Reputation storage format refused." end
    for key, value in pairs(settings) do
        if secret(key) or secret(value) or key ~= "autoReputationCapture" or
            type(value) ~= "boolean" then return nil, "Reputation setting format refused." end
    end
    if type(rawget(settings, "autoReputationCapture")) ~= "boolean" then
        return nil, "Reputation setting format refused." end
    local owners, bytes = 0, 0
    local seenTables = { [root] = true, [settings] = true, [characters] = true }
    for owner, history in pairs(characters) do
        if not guid(owner) or not plain(history) or seenTables[history] then
            return nil, "Reputation history format refused." end
        seenTables[history] = true
        owners = owners + 1
        if owners > 256 then return nil, "Reputation owner limit reached." end
        local count = 0
        for key in pairs(history) do
            if not integer(key, 1, 20) then return nil, "Reputation history format refused." end
            count = count + 1
        end
        if count == 0 or count > 20 then return nil, "Reputation history format refused." end
        local lastStamp, lastState = 0, nil
        for i = 1, count do
            local record = rawget(history, i)
            local stamp, state = parseRecord(record, owner)
            if not stamp or stamp <= lastStamp or state == lastState then
                return nil, "Reputation history format refused." end
            bytes = bytes + #record
            if bytes > 2097152 then return nil, "Reputation storage limit reached." end
            lastStamp, lastState = stamp, state
        end
    end
    return characters, settings, bytes, owners
end
local function method(namespace, key)
    if not plain(namespace) then return end
    local ok, fn = pcall(function() return namespace[key] end)
    if ok and not secret(fn) and type(fn) == "function" then return fn end
end
local function countRows(read)
    local ok, n = pcall(read)
    if ok and integer(n, 0, 256) then return n end
end
local function row(read, index)
    local ok, data = pcall(read, index)
    if not ok or not plain(data) then return nil, "Reputation row unavailable." end
    -- Copy scalar values immediately: the row table may be reused by the API.
    local fieldsOk, header, withRep, collapsed = pcall(function()
        return data.isHeader, data.isHeaderWithRep, data.isCollapsed
    end)
    if not fieldsOk or secret(header) or secret(withRep) or secret(collapsed) or
        type(header) ~= "boolean" or type(withRep) ~= "boolean" or
        type(collapsed) ~= "boolean" then return nil, "Reputation row unavailable." end
    if header then
        local named, name = pcall(function() return data.name end)
        if not named or secret(name) or type(name) ~= "string" or
            #name == 0 or #name > 256 then return nil, "Reputation header unavailable." end
        return "H" .. #name .. ":" .. name .. ":" .. tostring(withRep) ..
            ":" .. tostring(collapsed), nil, withRep, collapsed
    end
    if withRep or collapsed then
        return nil, "Reputation leaf classification unavailable." end
    local fields, id, reaction, minimum, maximum, value, accountWide = pcall(function()
        return data.factionID, data.reaction, data.currentReactionThreshold,
            data.nextReactionThreshold, data.currentStanding, data.isAccountWide
    end)
    if not fields or not integer(id, 1, MAX_ID) or not integer(reaction, 1, 16) or
        not integer(minimum, -MAX_VALUE, MAX_VALUE) or
        not integer(maximum, -MAX_VALUE, MAX_VALUE) or
        not integer(value, -MAX_VALUE, MAX_VALUE) or minimum >= maximum or
        value < minimum or value > maximum or secret(accountWide) or
        accountWide ~= false then return nil, "Reputation leaf or provenance unavailable." end
    local entry = table.concat({id, reaction, minimum, maximum, value}, ":")
    -- Header flags are compared on every row, not only headers.
    return "L" .. tostring(withRep) .. ":" .. tostring(collapsed) .. ":" .. entry,
        {id = id, entry = entry}
end
local function scan()
    local namespace = C_Reputation
    local count = method(namespace, "GetNumFactions")
    local read = method(namespace, "GetFactionDataByIndex")
    if not count or not read then return nil, "Reputation API unavailable." end
    local signatures, entries, ids = {}, {}, {}
    local visible, headerRep, collapsedHeaders = nil, 0, 0
    for pass = 1, 2 do
        local n = countRows(count)
        if not n or (visible and visible ~= n) then
            return nil, "Reputation view changed or unavailable." end
        visible = n
        for i = 1, n do
            local signature, leaf, withRep, collapsed = row(read, i)
            if not signature then return nil, leaf end
            if pass == 1 then
                signatures[i] = signature
                if leaf then
                    if ids[leaf.id] then return nil, "Duplicate faction ID." end
                    ids[leaf.id] = true
                    entries[#entries + 1] = leaf
                    if #entries > 200 then return nil, "Reputation leaf limit reached." end
                else
                    if withRep then headerRep = headerRep + 1 end
                    if collapsed then collapsedHeaders = collapsedHeaders + 1 end
                end
            elseif signatures[i] ~= signature then return nil, "Reputation view changed." end
        end
        if countRows(count) ~= n then return nil, "Reputation view changed." end
    end
    table.sort(entries, function(a, b) return a.id < b.id end)
    local wireEntries = {}
    local observedIDs = {}
    for i, leaf in ipairs(entries) do wireEntries[i] = leaf.entry; observedIDs[i] = leaf.id end
    return {rows = visible, leaves = #entries, headerRep = headerRep,
        collapsed = collapsedHeaders, entries = table.concat(wireEntries, ";"), ids = observedIDs}
end
local function context()
    local combat = InCombatLockdown
    if secret(combat) or type(combat) ~= "function" then
        return nil, nil, nil, "Combat status unavailable." end
    local ok, locked = pcall(combat)
    if not ok or secret(locked) or type(locked) ~= "boolean" or locked then
        return nil, nil, nil, "Reputation capture unavailable in combat." end
    local own, clock, build = UnitGUID, GetServerTime, GetBuildInfo
    if secret(own) or secret(clock) or secret(build) or type(own) ~= "function" or
        type(clock) ~= "function" or type(build) ~= "function" then
        return nil, nil, nil, "Reputation metadata unavailable." end
    local gotOwner, owner = pcall(own, "player")
    local gotTime, stamp = pcall(clock)
    local gotBuild, _, buildText = pcall(build)
    if not gotOwner or not gotTime or not gotBuild or not guid(owner) or
        not integer(stamp, 1, 253402300799) or secret(buildText) or
        type(buildText) ~= "string" then
        return nil, nil, nil, "Reputation metadata unavailable." end
    local number = unsigned(buildText, 1, MAX_ID)
    if not number then return nil, nil, nil, "Reputation metadata unavailable." end
    return owner, stamp, number
end
local function candidateRoot(source)
    if secret(source) then return nil, "Reputation storage protected." end
    if source == nil then
        return {schema = 1, settings = {autoReputationCapture = false}, characters = {}}, nil, 0
    end
    local characters, settings, _, owners = validate(source)
    if not characters then return nil, settings end
    local copy = {schema = 1, settings = {autoReputationCapture =
        settings.autoReputationCapture}, characters = {}}
    for owner, history in pairs(characters) do
        local entries = {}
        for i = 1, #history do entries[i] = history[i] end
        copy.characters[owner] = entries
    end
    return copy, nil, owners
end
local function budget(root)
    local fn = MclarionWow_ReputationStorageBudget
    if secret(fn) or type(fn) ~= "function" then return false end
    local ok, allowed = pcall(fn, root)
    return ok and not secret(allowed) and allowed == true
end
local function autoEnabled()
    if not primitives() then return false end
    local root = MclarionWowReputationData
    if secret(root) or root == nil then return false end
    local _, settings = validate(root)
    return settings and settings.autoReputationCapture == true or false
end
function MclarionWow_ReputationAutoEnabled()
    local ok, result = pcall(autoEnabled)
    return ok and result or false
end
local function setAuto(enabled)
    if not primitives() or secret(enabled) or type(enabled) ~= "boolean" then
        return nil, "Reputation setting unavailable." end
    local root, reason = candidateRoot(MclarionWowReputationData)
    if not root then return nil, reason end
    if root.settings.autoReputationCapture == enabled then return true end
    root.settings.autoReputationCapture = enabled
    if not budget(root) or not validate(root) then
        return nil, "Reputation storage budget refused." end
    MclarionWowReputationData = root
    return true
end
function MclarionWow_SetAutoReputationCapture(enabled)
    local ok, result, reason = pcall(setAuto, enabled)
    if not ok then return nil, "Reputation setting unavailable." end
    return result, reason
end
local function capture(manual)
    if not primitives() or secret(manual) or type(manual) ~= "boolean" then
        return nil, "Reputation capture mode unavailable." end
    local owner, stamp, build, reason = context()
    if not owner then return nil, reason end
    local root, storageReason, owners = candidateRoot(MclarionWowReputationData)
    if not root then return nil, storageReason end
    if not manual and not root.settings.autoReputationCapture then
        return nil, "Automatic reputation capture is off." end
    local view, scanReason = scan()
    if not view then return nil, scanReason end
    local function enrich()
        local fn = MclarionWow_EnrichObserved
        if not secret(fn) and type(fn) == "function" then pcall(fn, "reputation", view.ids, owner, stamp, build) end
    end
    local record = table.concat({"MHWOWR1", "forever", tostring(stamp), owner,
        tostring(build), "visible-ui", tostring(view.rows), tostring(view.leaves),
        tostring(view.headerRep), tostring(view.collapsed), view.entries}, "|")
    local recordStamp, state = parseRecord(record, owner)
    if not recordStamp then return nil, "Reputation record limit reached." end
    local previous = root.characters[owner]
    if previous then
        local priorStamp, priorState = parseRecord(previous[#previous], owner)
        if not priorStamp then return nil, "Reputation history format refused." end
        if state == priorState then enrich(); return true, "unchanged" end
        if stamp <= priorStamp then enrich(); return true, "same-second" end
    elseif owners >= 256 then return nil, "Reputation owner limit reached." end
    local stillOwner, _, _, checkReason = context()
    if not stillOwner or stillOwner ~= owner then
        return nil, checkReason or "Reputation owner changed." end
    local history = previous or {}
    history[#history + 1] = record
    if #history > 20 then table.remove(history, 1) end
    root.characters[owner] = history
    if not validate(root) or not budget(root) or not validate(root) then
        return nil, "Reputation storage budget refused." end
    MclarionWowReputationData = root
    enrich()
    return true, "saved"
end
function MclarionWow_CaptureReputation(manual)
    local ok, result, reason = pcall(capture, manual)
    if not ok then return nil, "Reputation capture unavailable." end
    return result, reason
end
