local ecs = ...
local serialize = import_package "ant.serialize"
local ro = ecs.component "render_obj"
local rendercore = ecs.clibs "render.core"
local bgfx = require "bgfx"
local math3d = require "math3d"

local function init_ro(r)
    r.worldmat = math3d.NULL
    r.prog        = 0xffffffff
    r.mesh        = 0
    r.depth       = 0
    r.discardflags= 0xff
    r.materials   = rendercore.queue_materials()
    return r
end

function ro.init(r)
    return init_ro(r)
end

function ro.remove(r)
    r.materials = nil
end

function ro.marshal(r)
    return serialize.pack(r)
end

function ro.unmarshal(r)
    return init_ro(serialize.unpack(r))
end