local cr = import_package "ant.compile_resource"
local serialize = import_package "ant.serialize"
local renderpkg = import_package "ant.render"
local crypt = require "crypt"
local declmgr   = renderpkg.declmgr

local function byte2hex(c)
	return ("%02x"):format(c:byte())
end
local function sha1(str)
	return crypt.sha1(str):gsub(".", byte2hex)
end

local function get_type(t)
    local types <const> = {
        u = "B", i = "I", f = "f",
    }
    local tt = types[t]
    assert(tt, "invalid type")
    return types[tt]
end

local function get_attrib_item(mesh, name)
    for i, vb in ipairs(mesh.vb) do
        local offset = 0
        local declname = vb.declname
        local stride = declmgr.layout_stride(declname)
        for d in declname:gmatch "%w+" do
            if d:sub(1, 3):match(name) then
                return {
                    offset = offset,
                    stride = stride,
                    memory = i,
                    type   = get_type(d:sub(6, 6)),
                }
            end
            offset = offset + declmgr.elem_size(d)
        end
    end
    --error(("not found attrib name:%s"):format(name))
end

local function load_(filename)
    local c = cr.read_file(filename)
    local mesh = serialize.unpack(c)

    local res = {memory = {}}
    for i, vb in ipairs(mesh.vb) do
        res.memory[i] = vb.memory[i]
    end

    res.vb = {
        pos    = get_attrib_item(mesh, "p"),
        normal = get_attrib_item(mesh, "n"),
        tangent= get_attrib_item(mesh, "T"),
        bitangent=get_attrib_item(mesh, "b"),
        uv0    = get_attrib_item(mesh, "t20"),
        uv1    = get_attrib_item(mesh, "t21"),
    }

    if mesh.ib then
        local function is_uint32(f)
            if f then
                return f:match "d"
            end
        end
        local t <const> = is_uint32(mesh.ib.flag) and "I" or "H"
        res.memory[#res.memory+1] = mesh.ib.memory
        res.ib = {
            offset = 0,
            stride = t == "I" and 4 or 2,
            memory = #res.memory,
            type = t,
        }
    end
    local bin = serialize.pack(res)
    return {
        name = "mesh-"..sha1(bin),
        value = bin,
    }
end

local cache = {}
local function load(filename)
    local r = cache[filename]
    if r then
        return r
    end
    r = load_(filename)
    cache[filename] = r
    return r
end

return {
    load = load
}
