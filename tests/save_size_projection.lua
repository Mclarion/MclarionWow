-- Synthetic-only whole-root size envelope. Not a game serializer or a writer.
local Projection = {}
local DEFAULT_LIMIT = 3000000 -- margin below the 4 MB manual upload boundary
local MAX_NODES = 50000
local MAX_DEPTH = 8

function Projection.estimate(root, limit)
    limit = limit or DEFAULT_LIMIT
    if type(limit) ~= "number" or limit < 4096 or limit > DEFAULT_LIMIT or
        limit ~= math.floor(limit) then return nil, "invalid limit" end
    local bytes, nodes, seen = 4096, 0, {}
    local function charge(amount)
        if amount > limit - bytes then return nil, "over budget" end
        bytes = bytes + amount
        return true
    end
    local function visit(value, depth)
        nodes = nodes + 1
        if nodes > MAX_NODES then return nil, "too many values" end
        local kind = type(value)
        if kind == "string" then
            -- A quoted byte can require up to four bytes of decimal escaping.
            return charge(4 * #value + 16)
        elseif kind == "number" then
            if value ~= value or value == math.huge or value == -math.huge or
                value ~= math.floor(value) or math.abs(value) > 9007199254740991 then
                return nil, "unsupported number"
            end
            return charge(64)
        elseif kind == "boolean" then
            return charge(16)
        elseif kind ~= "table" then
            return nil, "unsupported value"
        end
        if depth >= MAX_DEPTH then return nil, "too deep" end
        if seen[value] then return nil, "repeated table" end
        if getmetatable(value) ~= nil then return nil, "metatable" end
        seen[value] = true
        local ok, reason = charge(128 + depth * 32)
        if not ok then return nil, reason end
        for key, child in pairs(value) do
            nodes = nodes + 1
            if nodes > MAX_NODES then return nil, "too many values" end
            local keyKind = type(key)
            if keyKind == "string" then
                ok, reason = charge(128 + 4 * #key)
            elseif keyKind == "number" and key > 0 and
                key <= 2147483647 and key == math.floor(key) then
                ok, reason = charge(192)
            else
                return nil, "unsupported key"
            end
            if not ok then return nil, reason end
            ok, reason = visit(child, depth + 1)
            if not ok then return nil, reason end
        end
        return true
    end
    local ok, reason = visit(root, 0)
    if not ok then return nil, reason end
    return bytes
end

return Projection
