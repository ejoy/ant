
local foreach_save
local function foreach_single_save(component, arg, c, schema)
    if c.method and c.method.save then
        return c.method.save(component, arg)
    end
    if schema.map[c.type] then
        return foreach_save(component, arg, schema.map[c.type], schema)
    end
    if c.type == 'userdata' then
        assert "serialization isn't allowed."
    end
    return component
end

function foreach_save(component, arg, c, schema)
    if not c.type then
        local ret = {}
        for _, v in ipairs(c) do
            ret[v.name] = foreach_save(component[v.name], arg, v, schema)
        end
        if c.method and c.method.save then
            return c.method.save(ret, arg)
        end
        return ret
    end
    if c.array then
        local n = c.array == 0 and #component or c.array
        local ret = {}
        for i = 1, n do
            ret[i] = foreach_single_save(component[i], arg, c, schema)
        end
        return ret
    end
    if c.map then
        local ret = {}
        for k, v in pairs(component) do
            ret[k] = foreach_single_save(v, arg, c, schema)
        end
        return ret
    end
    return foreach_single_save(component, arg, c, schema)
end

local function gen_save(c, schema)
    return function (component, arg)
        return foreach_save(component, arg, c, schema)
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
    if c.type == 'userdata' then
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
            return c.method.load(ret, arg)
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
    return method
end
