local inited = false
local typeinfo

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
}
