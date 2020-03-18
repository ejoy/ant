local save = require "v2.save"

local m = {}

m.split = "/"

local typeinfo

local function split(s)
    local r = {}
    s:gsub('[^/]*', function (w) r[#r+1] = w end)
    return r
end

local function query_value(data, pathlst, ctype)
    if #pathlst == 0 then
        return data
    end
    if type(data) ~= "table" then
        return
    end
    local k = pathlst[1]
    table.remove(pathlst, 1)
    if k == '' then
        return query_value(data, pathlst, ctype)
    end
    local ti = typeinfo[ctype]
    if ti.array or ti.map then
        if ti.array then
            k = tonumber(k)
        end
        return query_value(data[k], pathlst, ti.type)
    end
    if not ti.type then
        for _, v in ipairs(ti) do
            if v.name == k then
                return query_value(data[k], pathlst, v.type)
            end
        end
        return
    end
    return query_value(data[k], pathlst, ti.type)
end

local function query(w, data, path)
    local pathlst = split(path)
    assert(#pathlst > 0)
    local k = pathlst[1]
    table.remove(pathlst, 1)
    typeinfo = w._class.component
    return query_value(data[k], pathlst, k)
end

local function set_value(data, pathlst, ctype, value)
    if type(data) ~= "table" then
        return false
    end
    local k = pathlst[1]
    table.remove(pathlst, 1)
    if k == '' then
        if #pathlst == 0 then
            return false
        end
        return set_value(data, pathlst, value)
    end
    local ti = typeinfo[ctype]
    if ti.array or ti.map then
        if ti.array then
            k = tonumber(k)
        end
        if #pathlst == 0 then
            data[k] = value
            return true
        end
        return set_value(data[k], pathlst, ti.type, value)
    end
    if not ti.type then
        for _, v in ipairs(ti) do
            if v.name == k then
                if #pathlst == 0 then
                    data[k] = value
                    return true
                end
                return set_value(data[k], pathlst, v.type, value)
            end
        end
        return false
    end
    if #pathlst == 0 then
        data[k] = value
        return true
    end
    return set_value(data[k], pathlst, ti.type, value)
end

local function set(w, data, path, value)
    local pathlst = split(path)
    assert(#pathlst > 0)
    local k = pathlst[1]
    table.remove(pathlst, 1)
    if #pathlst == 0 then
        data[k] = value
        return true
    end
    typeinfo = w._class.component
    set_value(data[k], pathlst, k, value)
end

function m.query(w, eid, path)
    local e = save.entity(w, eid)
    if not path then
        return e
    end
    return query(w, e, path)
end

function m.set(w, eid, path, value)
    local e = save.entity(w, eid)
    if set(w, e, path, value) then
        w:reset_entity(eid, e)
        return true
    end
    return false
end

return m
