local ecs = ...
local world = ecs.world

local ctrunkid  = require "trunkid_class"
local constant  = require "constant"

local bgfx      = require "bgfx"

local ies = world:interface "ant.scene|ientity_state"
local itr = ecs.interface "itrunk_render"

--[[
    vertex buffer for quad sphere have 4 stream vertex
    1. position
    2. color
    3. uv0 for color texture
    4. uv1 for alpha texture
]]
function itr.fill_vertex(eid)
    local qs = world[eid]

end

--TODO: need remove, just for test
function itr.generate_quad_uv_index(eid)

end

function itr.fill_uv(eid, uv_indices, stage)
    
end

function itr.reset_trunk(eid, trunkid)
    local e = world[eid]
    local t = e._trunk
    local qs = assert(world[t.qseid])._quad_sphere
    t.id = trunkid

    ies.set_state(eid, "visible", true)

    local vertices, aabb = ctrunkid.tile_vertices(trunkid, qs, constant.tile_pre_trunk_line)
    e._bounding.aabb.m = aabb
    local rc = e._rendercache
    rc.aabb = e._bounding.aabb

    local vb = rc.vb
    local poshandle = vb.handles[1]
    bgfx.update(poshandle, 0, bgfx.memory_buffer("fff", vertices), constant.vb_layout[1].handle)

end