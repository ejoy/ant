local assetmgr = import_package "ant.asset"

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

local w
local path
local typeinfo
local foreach_init_1

local poppath = setmetatable({}, {__close=function() path[#path] = nil end})
local function pushpath(v)
    path[#path+1] = v
    return poppath
end

local function foreach_init_2(c, args)
    if c.type == 'primtype' then
        assert(args ~= nil)
        return args
    end
    if c.type == 'entityid' then
        if type(args) == "number" then
            return args
        else
            return w:find_entity(args) or args
        end
    end
    local ti = typeinfo[c.type]
    assert(ti, "unknown type:" .. c.type)
    if c.array then
        if type (args) == "table" then
            local n = c.array == 0 and (args and #args or 0) or c.array
            local res = {}
            for i = 1, n do
                local _ <close> = pushpath(i)
                res[i] = foreach_init_1(ti, args[i])
            end
            return res
        else
            --TODO
            local res = {}
            local _ <close> = pushpath(1)
            res[1] = foreach_init_1(ti, args)
            return res
        end
    end
    if c.map then
        local res = {}
        if args then
            for k, v in sortpairs(args) do
                if type(k) == "string" then
                    local _ <close> = pushpath(k)
                    res[k] = foreach_init_1(ti, v)
                end
            end
        end
        return res
    end
    return foreach_init_1(ti, args)
end

function foreach_init_1(c, args)
    if c.type == 'tag' then
        assert(args == true or args == nil)
        return args
    end

    local ret
    if c.type then
        ret = foreach_init_2(c, args)
    else
        ret = {}
        for _, v in ipairs(c) do
            if args[v.name] == nil and v.attrib and v.attrib.opt then
                goto continue
            end
            assert(v.type)
            local _ <close> = pushpath(v.name)
            ret[v.name] = foreach_init_2(v, args[v.name])
            ::continue::
        end
    end
    if c.methodfunc and c.methodfunc.init then
        ret = c.methodfunc.init(ret)
    end
    return ret
end

local function foreach_init(c, args)
    local ti = assert(typeinfo[c], "unknown type:" .. c)
    if ti.type == 'tag' then
        assert(args == true or args == nil)
        return args
    end
    local res = foreach_init_1(ti, args)
    assert(res ~= nil)
    return res
end

local function init(w_, c, args)
    w = w_
    typeinfo = w._class.component
    path = {}
    local _ <close> = pushpath(c.name)
    return foreach_init(c, args)
end

local function delete(c, component)
    if c.methodfunc and c.methodfunc.delete then
        c.methodfunc.delete(component)
    end
end

local function gen_ref(c)
    if c.ref ~= nil then
        return c.ref
    end
    if not c.type then
        c.ref = true
        for _,v in ipairs(c) do
            v.ref = gen_ref(v)
        end
        return c.ref
    end
    if c.type == 'primtype' then
        c.ref = false
        return c.ref
    end
    assert(typeinfo[c.type], "unknown type:" .. c.type)
    c.ref = gen_ref(typeinfo[c.type])
    return c.ref
end

local function solve(w)
    typeinfo = w._class.component
    local schema = w._schema_data
    for _,v in ipairs(schema.list) do
        if v.uncomplete then
            error(v.name .. " is uncomplete")
        end
    end
    for k, parent in pairs(schema._undefined) do
        if typeinfo[parent] and not typeinfo[k] then
            error(k .. " is undefined in " .. parent)
        end
    end
    for _,v in pairs(typeinfo) do
        gen_ref(v)
    end
end

return {
    init = init,
    delete = delete,
    solve = solve,
}
