local solve_depend = require "solve_depend"

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

local function foreach_init_2(w, c, args)
    if c.has_default or c.type == 'primtype' then
        return args
    end
    assert(w._components[c.type], "unknown type:" .. c.type)
    if c.array then
        local n = c.array == 0 and (args and #args or 0) or c.array
        local ret = {}
        for i = 1, n do
            ret[i] = w:create_component(c.type, args[i])
        end
        return ret
    end
    if c.map then
        local ret = {}
        if args then
            for k, v in sortpairs(args) do
                ret[k] = w:create_component(c.type, v)
            end
        end
        return ret
    end
    return w:create_component(c.type, args)
end

local function foreach_init_1(w, c, args)
    local ret
    if c.type then
        ret = foreach_init_2(w, c, args)
    else
        ret = {}
        for _, v in ipairs(c) do
            if args[v.name] == nil and v.attrib and v.attrib.opt then
                goto continue
            end
            assert(v.type)
            ret[v.name] = foreach_init_2(w, v, args[v.name])
            ::continue::
        end
    end
    if c.method and c.method.init then
        ret = c.method.init(ret)
    end
    return ret
end

local foreach_delete_1
local function foreach_delete_2(w, c, component)
    if c.type == 'primtype' then
        return
    end
    assert(w._components[c.type], "unknown type:" .. c.type)
    foreach_delete_1(w, w._components[c.type], component)
end

function foreach_delete_1(w, c, component, e)
    if c.method and c.method.delete then
        c.method.delete(component, e)
    end
    if not c.type then
		for _, v in ipairs(c) do
			if component[v.name] == nil and v.attrib and v.attrib.opt then
				goto continue
			end
			assert(v.type)
            foreach_delete_1(w, v, component[v.name])
			::continue::
		end
        return
    end
    if c.array then
        local n = c.array == 0 and #component or c.array
        for i = 1, n do
            foreach_delete_2(w, c, component[i])
        end
        return
    end
    if c.map then
        for _, v in pairs(component) do
            foreach_delete_2(w, c, v)
        end
        return
    end
    foreach_delete_2(w, c, component)
end

local typeinfo
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
    typeinfo = w._components
    local res = solve_depend(typeinfo)
    for i, name in ipairs(res) do
        typeinfo[name].sortid = i
    end
    for _,v in pairs(typeinfo) do
        gen_ref(v)
    end
end

return {
    init = foreach_init_1,
    delete = foreach_delete_1,
    solve = solve,
}
