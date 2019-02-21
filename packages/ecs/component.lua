local function sortpairs(t)
    local sort = {}
    for k in pairs(t) do
        sort[#sort+1] = k
    end
    table.sort(sort)
    local n = 1
    return function ()
        local k = sort[n]
        if k == nil then
            return
        end
        n = n + 1
        return k, t[k]
    end
end

local function foreach_init_2(c, w)
    if c.has_default or c.type == 'primtype' then
        if type(c.default) == 'function' then
            return c.default()
        end
        return c.default
    end
    assert(w.schema.map[c.type], "unknown type:" .. c.type)
    if c.array then
        if c.array == 0 then
            return {}
        end
        local ret = {}
        for i = 1, c.array do
            ret[i] = w:create_component(c.type)
        end
        return ret
    end
    if c.map then
        return {}
    end
    return w:create_component(c.type)
end

local function foreach_init_1(c, w)
    local ret
    if c.type then
        ret = foreach_init_2(c, w)
    else
        ret = {}
        for _, v in ipairs(c) do
            assert(v.type)
            ret[v.name] = foreach_init_2(v, w)
        end
    end
    if c.method and c.method.init then
        ret = c.method.init(ret)
    end
    return ret
end

local function gen_init(c, w)
    return function()
        return foreach_init_1(c, w)
    end
end

local function foreach_initp_2(c, w, args)
    if c.has_default or c.type == 'primtype' then
        return args
    end
    assert(w.schema.map[c.type], "unknown type:" .. c.type)
    if c.array then
        local n = c.array == 0 and (args and #args or 0) or c.array
        local ret = {}
        for i = 1, n do
            ret[i] = w:create_component_with_args(c.type, args[i])
        end
        return ret
    end
    if c.map then
        local ret = {}
        if args then
            for k, v in sortpairs(args) do
                ret[k] = w:create_component_with_args(c.type, v)
            end
        end
        return ret
    end
    return w:create_component_with_args(c.type, args)
end

local function foreach_initp_1(c, w, args)
    local ret
    if c.type then
        ret = foreach_initp_2(c, w, args)
    else
        ret = {}
        for _, v in ipairs(c) do
            if args[v.name] == nil and v.attrib and v.attrib.opt then
                goto continue
            end
            assert(v.type)
            ret[v.name] = foreach_initp_2(v, w, args[v.name])
            ::continue::
        end
    end
    if c.method and c.method.init then
        ret = c.method.init(ret)
    end
    return ret
end

local function gen_initp(c, w)
    return function(args)
        return foreach_initp_1(c, w, args)
    end
end

local foreach_delete_1
local function foreach_delete_2(component, c, schema)
    if c.type == 'primtype' then
        return
    end
    assert(schema.map[c.type], "unknown type:" .. c.type)
    foreach_delete_1(component, schema.map[c.type], schema)
end

function foreach_delete_1(component, c, schema)
    if c.method and c.method.delete then
        c.method.delete(component)
        return
    end
    if not c.type then
        for _, v in ipairs(c) do
            foreach_delete_1(component, v, schema)
        end
        return
    end
    if c.array then
        local n = c.array == 0 and #component or c.array
        for i = 1, n do
            foreach_delete_2(component[i], c, schema)
        end
        return
    end
    if c.map then
        for _, v in pairs(component) do
            foreach_delete_2(v, c, schema)
        end
        return
    end
    foreach_delete_2(component, c, schema)
end

local function gen_delete(c, schema)
    return function(component)
        return foreach_delete_1(component, c, schema)
    end
end

return function(c, w)
    return {
        init = gen_init(c, w),
        initp = gen_initp(c, w),
        delete = gen_delete(c, w.schema)
    }
end
