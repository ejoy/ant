local ecs = ...

local m = ecs.component "mesh"

local bgfx = require "bgfx"
local declmgr = import_package "ant.render".declmgr

local proxy_vb = {}
function proxy_vb:__index(k)
    if k == "handle" then
        local h = bgfx.create_vertex_buffer(self.memory, declmgr.get(self.declname).handle)
        self.handle = h
        return h
    end
end

local proxy_ib = {}
function proxy_ib:__index(k)
    if k == "handle" then
        local h = bgfx.create_index_buffer(self.memory, self.flag)
        self.handle = h
        return h
    end
end

function m:init()
    local vb = self.vb
    local handles = {}
    for _, v in ipairs(vb) do
        setmetatable(v, proxy_vb)
    end
    local ib = self.ib
    if ib then
        setmetatable(ib, proxy_ib)
    end
    return self
end
