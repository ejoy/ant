local math3d = require "math3d"
local ecs = ...

local constant  = require "constant"
local bgfx      = require "bgfx"

local tt = ecs.transform "trunk_transform"
function tt.process_entity(e)
    e._trunk = {
        qseid = e.trunk.qseid
    }
end

local tbt = ecs.transform "trunk_bounding_transform"
function tbt.process_entity(e)
    e._bounding.aabb = math3d.ref(math3d.aabb())
end

local tmt = ecs.transform "trunk_mesh_transform"

local vblayout = constant.vb_layout

local vn = constant.vertices_per_trunk

function tmt.process_entity(e)
    local rc = e._rendercache
    rc.ib = constant.trunk_ib.buffer
    rc.vb = {
        start = 0,
        num = vn,
        handle = {
            bgfx.create_dynamic_vertex_buffer(vn, vblayout[1].handle),
            bgfx.create_dynamic_vertex_buffer(vn, vblayout[2].handle),
            bgfx.create_dynamic_vertex_buffer(vn, vblayout[3].handle),
        }
    }
end