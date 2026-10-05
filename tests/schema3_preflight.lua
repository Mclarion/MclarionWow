-- Test-only schema-3 preflight reference. Does not touch the installed addon,
-- SavedVariables, or the WoW serializer; no live secret-value checks.
local Contract = dofile("tests/progression_contract.lua")
local Projection = dofile("tests/save_size_projection.lua")
local Preflight = {}

local function clone(value, depth, seen)
    if type(value) ~= "table" then return value end
    if depth >= 8 or getmetatable(value) ~= nil or seen[value] then
        return nil, "unsupported source graph"
    end
    seen[value] = true
    local result = {}
    for key, child in pairs(value) do
        local copied, reason = clone(child, depth + 1, seen)
        if copied == nil then return nil, reason end
        result[key] = copied
    end
    return result
end

function Preflight.prepare(source, progression, limit)
    if type(source) ~= "table" or getmetatable(source) ~= nil then
        return nil, "invalid source"
    end
    local settings = rawget(source, "settings")
    if rawget(source, "schema") ~= 2 or type(settings) ~= "table" or
        getmetatable(settings) ~= nil or rawget(source, "progression") ~= nil or
        rawget(settings, "autoQuestCapture") ~= nil or
        rawget(settings, "autoReputationCapture") ~= nil or
        type(progression) ~= "table" or getmetatable(progression) ~= nil then
        return nil, "invalid source"
    end
    if not Projection.estimate(source) then return nil, "unsupported source" end
    -- Bound the new graph before cloning it, not only after composing the root.
    if not Projection.estimate(progression) then return nil, "unsupported observations" end
    local seen = {}
    local candidate = clone(source, 0, seen)
    if not candidate then return nil, "unsupported source" end
    local observations = clone(progression, 1, seen)
    if not observations then return nil, "unsupported observations" end
    candidate.schema = 3
    candidate.settings.autoQuestCapture = false
    candidate.settings.autoReputationCapture = false
    candidate.progression = observations
    if not Contract.validateRoot(candidate) then return nil, "invalid candidate" end
    local size = Projection.estimate(candidate, limit)
    if not size then return nil, "candidate over budget or unsupported" end
    return candidate, size
end

return Preflight
