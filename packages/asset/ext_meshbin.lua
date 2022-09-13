local cr = import_package "ant.compile_resource"
local serialize = import_package "ant.serialize"
local math3d = require "math3d"
local bgfx = require "bgfx"
local declmgr = import_package "ant.render".declmgr
local fs = require "filesystem"

local proxy_vb = {}
function proxy_vb:__index(k)
    if k == "handle" then
        assert(#self.memory <= 3 and (type(self.memory[1]) == "userdata" or type(self.memory[1]) == "string"))
        local membuf = bgfx.memory_buffer(table.unpack(self.memory))
        local h = bgfx.create_vertex_buffer(membuf, declmgr.get(self.declname).handle)
        self.handle = h
        return h
    end
end

local proxy_ib = {}
function proxy_ib:__index(k)
    if k == "handle" then
        assert(#self.memory <= 3 and (type(self.memory[1]) == "userdata" or type(self.memory[1]) == "string"))
        local membuf = bgfx.memory_buffer(table.unpack(self.memory))
        local h = bgfx.create_index_buffer(membuf, self.flag)
        self.handle = h
        return h
    end
end

local function init(mesh)
    local vb = mesh.vb
    setmetatable(vb, proxy_vb)

    local ib = mesh.ib
    if ib then
        setmetatable(ib, proxy_ib)
    end
    return mesh
end

local function destroy_handle(v)
    if v then
        if v.owned then
            bgfx.destroy(v.handle)
            v.owned = nil
        end
        v.handle = nil
    end
end

local function delete(mesh)
    destroy_handle(mesh.vb)
    destroy_handle(mesh.ib)
end

local function create_bounding(bounding)
    if bounding then
        bounding.aabb = math3d.mark(math3d.aabb(bounding.aabb[1], bounding.aabb[2]))
    end
end

local function loader(filename)
    local c = cr.read_file(filename)
    local mesh = serialize.unpack(c)
    create_bounding(mesh.bounding)
    return init(mesh)
end

local function unloader(filename, res, obj)
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
