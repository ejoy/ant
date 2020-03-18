local saveEntity = require "v2.save".entity

local m = {}

local function split(s)
    local r = {}
    s:gsub('[^/]*', function (w)
        r[#r+1] = w:gsub("~1", "/"):gsub("~0", "~")
    end)
    return r
end

local function isArray(t)
    local first_value = next(t)
    if first_value == nil then
        local mt = getmetatable(t)
        if mt and mt.__name == 'serialize.map' then
            return false
        end
        return true
    end
    if type(first_value) == "number" then
        return true
    end
    return false
end

local function isValidEntity(e)
    return type(e) == "table" and not isArray(e)
end

local function queryValue(data, pathlst, n)
    if type(data) ~= "table" then
        return
    end
    local k = pathlst[n]
    if isArray(data) then
        if k == "-" then
            k = #data + 1
        else
            k = tonumber(k)
        end
    end
    if n == #pathlst then
        return data[k]
    end
    return queryValue(data[k], pathlst, n + 1)
end

function m.query(w, eid, path)
    local e = saveEntity(w, eid)
    if path == '' then
        return e
    end
    return queryValue(e, split(path), 1)
end

local function setValue(data, pathlst, value, n)
    if type(data) ~= "table" then
        return false
    end
    local k = pathlst[n]
    if isArray(data) then
        k = tonumber(k)
    end
    if n == #pathlst then
        data[k] = value
        return true
    end
    return setValue(data[k], pathlst, value, n + 1)
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
    if not setValue(e, split(path), value, 1) then
        return false
    end
    w:reset_entity(eid, e)
    return true
end

return m
