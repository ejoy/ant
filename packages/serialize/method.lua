
local pool = {}

local nonref = {int=true,real=true,string=true,boolean=true,primtype=true}

local foreach_save_1
local function foreach_save_3(component, c, schema)
    if nonref[c.type] then
        if c.method and c.method.save then
            return c.method.save(component)
        end
        assert(c.type ~= 'primtype', "serialization isn't allowed.")
        return component
    end
    assert(schema.map[c.type], "unknown type:" .. c.type)

    if pool[component] then
        return pool[component]
    end
    local result
    if c.method and c.method.save then
        result = c.method.save(component)
    else
        result = foreach_save_1(component, schema.map[c.type], schema)
    end
    pool[component] = result
    return result
end

local function foreach_save_2(component, c, schema)
    if c.array then
        local n = c.array == 0 and #component or c.array
        local ret = {}
        for i = 1, n do
            ret[i] = foreach_save_3(component[i], c, schema)
        end
        return ret
    end
    if c.map then
		local ret = {}
        for k, v in pairs(component) do
			ret[k] = foreach_save_3(v, c, schema)
		end
        return ret
    end
    return foreach_save_3(component, c, schema)
end

function foreach_save_1(component, c, schema)
    if not c.type then
        local ret = {}
        for _, v in ipairs(c) do
            ret[v.name] = foreach_save_2(component[v.name], v, schema)
        end
        if c.method and c.method.save then
            c.method.save(ret)
            return ret
        end
        return ret
    end
    return foreach_save_2(component, c, schema)
end

local function gen_save(c, schema)
    return function (component)
        return foreach_save_1(component, c, schema)
    end
end


local foreach_load
local function foreach_single_load(component, arg, c, schema)
    if c.method and c.method.load then
        return c.method.load(component, arg)
    end
    if schema.map[c.type] then
        return foreach_load(component, arg, schema.map[c.type], schema)
    end
    if c.type == 'primtype' then
        assert "serialization isn't allowed."
    end
    return component
end

function foreach_load(component, arg, c, schema)
    if not c.type then
        local ret = {}
        for _, v in ipairs(c) do
            ret[v.name] = foreach_load(component[v.name], arg, v, schema)
        end
        if c.method and c.method.load then
            c.method.load(ret, arg)
            return ret
        end
        return ret
    end
    if c.array then
        local n = c.array == 0 and #component or c.array
        local ret = {}
        for i = 1, n do
            ret[i] = foreach_single_load(component[i], arg, c, schema)
        end
        return ret
    end
    if c.map then
        local ret = {}
        for k, v in pairs(component) do
            ret[k] = foreach_single_load(v, arg, c, schema)
        end
        return ret
    end
    return foreach_single_load(component, arg, c, schema)
end

local function gen_load(c, schema)
    return function (component, arg)
        return foreach_load(component, arg, c, schema)
    end
end

return function (w)
    local method = {save={},load={}}
    local schema = w.schema
    local typeinfo = w.schema.map
    for k in pairs(w._component_type) do
        method.save[k] = gen_save(typeinfo[k], schema)
        method.load[k] = gen_load(typeinfo[k], schema)
    end
    method.reset = function()
        pool = {}
    end
    return method
end
