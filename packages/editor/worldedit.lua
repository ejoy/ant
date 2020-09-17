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
        set(prefab.__class, path, value)
        if need_update(pathlst) then
            for _, instance in ipairs(mgr[prefab]) do
                set_entity(world, instance[idx], pathlst, value)
            end
        end
        return true
    elseif catalog == "action" then
        set(prefab[idx].template, "/"..table.concat(pathlst, "/", 3), value)
        set(prefab.__class, path, value)
        if pathlst[3] == "mount" then
            local object = world._class.action[pathlst[3]]
            assert(object and object.init)
            local target = prefab.__class[idx].action[pathlst[3]]
            object.init(mgr[prefab][1], idx, target)
        end
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
        return get(prefab.__class, path)
    end
    return false
end

local mt = {}
mt.__index = mt

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

function mt:add_entity(curr_prefab, template)
    local edit_prefab = assetmgr.edit(curr_prefab)
    edit_prefab.__class[#edit_prefab.__class+1] = template
    if template.prefab then
        edit_prefab[#edit_prefab+1] = {
            prefab = assetmgr.resource(template.prefab, self.world)
        }
    else
        edit_prefab[#edit_prefab+1] = world:create_entity_template(template)
    end
    
end

function mt:prefab_del(idx)
    for i, t in prefab.__class do
        if t.action.mount > idx then
            t.action.mount = t.action.mount - 1
        end
    end

    table.remove(prefab, idx)
    table.remove(prefab.__class, idx)
end

function mt:prefab_set(prefab, path, value)
    set_prefab(self.world, prefab, path, value)
end

function mt:prefab_get(prefab, path)
    local _, res = get_prefab(prefab, path)
    return res
end

local function deepcopy(t)
    if type(t) ~= "table" then
        return t
    end
    local r = {}
    for k, v in pairs(t) do
        r[k] = deepcopy(v)
    end
    return r
end

function mt:prefab_copy(prefab)
    local newprefab = deepcopy(prefab)
    mgr[newprefab] = {}
    return newprefab
end

return function(world)
    return setmetatable({world=world}, mt)
end
