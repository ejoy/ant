local bgfx      = require "bgfx"
local fastio    = require "fastio"
local setting   = import_package "ant.settings"
local aio       = import_package "ant.io"
local layoutmgr = import_package "ant.render".layoutmgr
local serialize = import_package "ant.serialize"

local USE_CS_SKINNING <const> = setting:get "graphic/skinning/use_cs"

local function is_cs_skinning_buffer(layoutname)
    return USE_CS_SKINNING and ("iw"):match(layoutname:sub(1, 1))
end

local proxy_vb = {}

local function mem2str(obj)
    local m = obj.memory
    obj.memory = nil
    local data = m[1]
    local offset = m[2]
    local size = m[3]
    local datatype = type(data)
    if datatype == "userdata" then
        return fastio.tostring(data, offset, size)
    end
    assert(datatype == "string")
    return data:sub(offset, offset+size)
end

local function mem2bgfx(obj)
    local m = obj.memory
    obj.memory = nil
    local data = m[1]
    local offset = m[2]
    local size = m[3]
    local datatype = type(data)
    if datatype == "userdata" then
        return bgfx.memory_buffer(fastio.wrap(data), offset, size)
    end
    assert(datatype == "string")
    return bgfx.memory_buffer(data, offset, size)
end

function proxy_vb:__index(k)
    if k == "handle" then
        local membuf = mem2bgfx(self)
        local layoutname = self.declname
        local layouthandle = layoutmgr.get(layoutname).handle
        local h = is_cs_skinning_buffer(layoutname) and
                bgfx.create_dynamic_vertex_buffer(membuf, layouthandle, "r") or
                bgfx.create_vertex_buffer(membuf, layouthandle)
        self.handle = h
        return h
    end

    if k == "str" then
        local str = mem2str(self)
        self.str = str
        return str
    end
end

local proxy_ib = {}
function proxy_ib:__index(k)
    if k == "handle" then
        local membuf = mem2bgfx(self)
        local h = bgfx.create_index_buffer(membuf, self.flag)
        self.handle = h
        return h
    end

    if k == "str" then
        local str = mem2str(self)
        self.str = str
        return str
    end
end

local function init(mesh)
    local vb = mesh.vb
    setmetatable(vb, proxy_vb)
    local vb2 = mesh.vb2
    if vb2 then
        setmetatable(vb2, proxy_vb)
    end
    local ib = mesh.ib
    if ib then
        setmetatable(ib, proxy_ib)
    end
    return mesh
end

local function destroy_handle(v)
	if v then
		if not v.memory then
			bgfx.destroy(v.handle)
		end
		v.handle = nil
	end
end

local function delete(mesh)
    destroy_handle(mesh.vb)
    destroy_handle(mesh.vb2)
    destroy_handle(mesh.ib)
end

local function parent_path(v)
    return v:match("^(.+)/[^/]*$")
end

local function load_mem(buf, meshfile)
    if buf then
        local m = buf.memory
        local binname = m[1]
        assert(type(binname) == "string" and (binname:match "%.[iv]bbin" or binname:match "%.[iv]b[2]bin"))

        m[1] = aio.readall_v(parent_path(meshfile) .. "/" .. binname)
    end
end

local function loader(filename)
    local mesh = serialize.load(filename)

    load_mem(mesh.vb, filename)
    load_mem(mesh.vb2, filename)
    load_mem(mesh.ib, filename)

    return init(mesh)
end

local function unloader(res, obj)
    delete(res)
end

return {
    init = init,
    delete = delete,
    proxy_vb = function (vb)
        return setmetatable(vb, proxy_vb)
    end,
    proxy_ib = function (ib)
        return setmetatable(ib, proxy_ib)
    end,
    loader = loader,
    unloader = unloader,
}