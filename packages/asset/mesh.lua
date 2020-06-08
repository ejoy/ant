local ecs = ...

local m = ecs.component "mesh"

local bgfx = require "bgfx"
local declmgr = import_package "ant.render".declmgr

function m:init()
    local vb = self.vb
    local handles = {}
    for _, v in ipairs(vb.values) do
        handles[#handles+1] = bgfx.create_vertex_buffer(v.memory, declmgr.get(v.declname).handle)
    end
    self.vb.handles = handles
    local ib = self.ib
    if ib then
        local v = ib.value
        ib.handle = bgfx.create_index_buffer(v.memory, v.flag)
    end
    return self
end
