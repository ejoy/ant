local inited = false
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

local function init (w)
    if inited then
        return
    end
    inited = true
    typeinfo = w._schema.map
    for _,v in pairs(typeinfo) do
        gen_ref(v)
    end
end

return {
    init = init,
}
