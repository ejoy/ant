local assetmgr = import_package "ant.asset"

local mgr = {}

local function split(s)
    local r = {}
    s:gsub('[^/]*', function (w)
        r[#r+1] = w:gsub("~1", "/"):gsub("~0", "~")
    end)
    return r
end

local ObjectMetatable = {} --TODO

local function isArray(t)
    local next, s = pairs(t)
    local first_value = next(s)
    if first_value == nil then
        if getmetatable(t) == ObjectMetatable then
            return false
        end
        return true
    end
    if type(first_value) == "number" then
        return true
    end
    return false
end

local function query_(data, pathlst, n)
    if type(data) ~= "table" then
        return
    end
    local k = pathlst[n]
    local isarray = isArray(data)
    if isarray then
        if k == "-" then
            k = #data + 1
        else
            k = tonumber(k)
            if k == nil or math.type(k) ~= "integer" or k <= 0 or k > #data + 1 then
                return
            end
        end
    end
    if n == #pathlst then
        return data, k, isarray
    end
    return query_(data[k], pathlst, n + 1)
end

local function set(data, path, value)
    if type(path) ~= "string" then
        return false
    end
    if path:sub(1,1) ~= "/" then
        return false
    end
    local t, k = query_(data, split(path:sub(2)), 1)
    if not t then
        return false
    end
    t[k] = value
    return true
end

local function get(data, path)
    if type(path) ~= "string" then
        return false
    end
    if path:sub(1,1) ~= "/" then
        return false
    end
    local t, k = query_(data, split(path:sub(2)), 1)
    if not t then
        return false
    end
    return true, t[k]
end

local function set_entity(world, eid, path, value)
end

local function need_update(pathlst)
    return false
end

local function set_prefab(world, prefab, path, value)
    local pathlst = split(path:sub(2))
    local idx = tonumber(pathlst[1])
    if idx == nil or math.type(idx) ~= "integer" or idx <= 0 or idx > #prefab + 1 then
        return false
    end
    local catalog = pathlst[2]
    if catalog == "data" then
        set(prefab[idx].template, "/"..table.concat(pathlst, "/", 3), value)
        set(prefab.data, path, value)
        if need_update(pathlst) then
            for _, instance in ipairs(mgr[prefab]) do
                set_entity(world, instance[idx], pathlst, value)
            end
        end
        return true
    end
    return false
end

local function get_prefab(prefab, path)
    local pathlst = split(path:sub(2))
    local idx = tonumber(pathlst[1])
    if idx == nil or math.type(idx) ~= "integer" or idx <= 0 or idx > #prefab + 1 then
        return false
    end
    local catalog = pathlst[2]
    if catalog == "data" then
        return get(prefab.data, path)
    end
    return false
end

local mt = {}

function mt:prefab_template(filename)
	local prefab = assetmgr.resource(filename, self.world)
    mgr[prefab] = {}
    return prefab
end

function mt:prefab_instance(prefab, args)
    local instance = self.world:instance_prefab(prefab, args)
    table.insert(mgr[prefab], instance)
    return instance
end

function mt:prefab_set(prefab, path, value)
    set_prefab(self.world, prefab, path, value)
end

function mt:prefab_get(prefab, path)
    local _, res = get_prefab(prefab, path)
    return res
end

return function(world)
    return setmetatable({world=world}, {__index=mt})
end
