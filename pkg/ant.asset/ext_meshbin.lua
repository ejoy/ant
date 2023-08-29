local setting   = import_package "ant.settings"

local bgfx      = require "bgfx"
local fastio    = require "fastio"
local datalist  = require "datalist"
local async     = require "async"
local layoutmgr = import_package "ant.render".layoutmgr

local USE_CS_SKINNING<const> = setting:get "graphic/skinning/use_cs"

local function is_cs_skinning_buffer(layoutname)
    return USE_CS_SKINNING and ("iw"):match(layoutname:sub(1, 1))
end

local proxy_vb = {}
function proxy_vb:__index(k)
    if k == "handle" then
        assert(#self.memory <= 3 and (type(self.memory[1]) == "userdata" or type(self.memory[1]) == "string"))
        local membuf = bgfx.memory_buffer(table.unpack(self.memory))
        local layoutname = self.declname
        local layouthandle = layoutmgr.get(layoutname).handle
        local h = is_cs_skinning_buffer(layoutname) and
                bgfx.create_dynamic_vertex_buffer(membuf, layouthandle, "r") or
                bgfx.create_vertex_buffer(membuf, layouthandle)
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

local function parent_path(v)
    return v:match("^(.+)/[^/]*$")
end

local function load_mem(m, filename)
    local binname = m[1]
    assert(type(binname) == "string" and (binname:match "%.[iv]bbin" or binname:match "%.[iv]b[2]bin"))

    m[1] = fastio.readall(async.compile(parent_path(filename) .. "/" .. binname))
end

local function loader(filename)
    local local_filename = async.compile(filename)
    local mesh = datalist.parse(fastio.readall(local_filename))

    local vb = assert(mesh.vb)
    load_mem(vb.memory, filename)
    local vb2 = mesh.vb2
    if vb2 then
        load_mem(vb2.memory, filename)
    end 
    local ib = mesh.ib
    if ib then
        load_mem(ib.memory, filename)
    end
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