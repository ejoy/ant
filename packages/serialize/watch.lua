local patch = require "patch"
local saveEntity = require "v2.save".entity

local m = {}

local function isValidEntity(e)
    return type(e) == "table"
end

function m.query(w, eid, path)
    local e = saveEntity(w, eid)
    if path == '' then
        return e
    end
    local ok, res = patch.get(e, path)
    if ok then
        return
    end
    return res
end

function m.set(w, eid, path, value)
    local e = saveEntity(w, eid)
    if path == '' then
        if not isValidEntity(value) then
            return false
        end
        w:reset_entity(eid, value)
        return true
    end
    if not patch.set(e, path, value) then
        return false
    end
    w:reset_entity(eid, e)
    return true
end

return m
