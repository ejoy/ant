local inited = false
local typeinfo

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

local function gen_ref(c)
    if c.ref ~= nil then
        return c.ref
    end
    if not c.type then
        for _,v in ipairs(c) do
            gen_ref(v)
        end
        c.ref = true
        return c.ref
    end
    if c.type == 'primtype' then
        c.ref = false
        return c.ref
    end
    assert(typeinfo[c.type], "unknown type:" .. c.type)
    c.ref = gen_ref(typeinfo[c.type])
end

local function init (w)
    if inited then
        return
    end
    inited = true
    typeinfo = w.schema.map
    for _,v in pairs(typeinfo) do
        gen_ref(v)
    end
end

return {
    init = init,
    load = foreach_load,
}
