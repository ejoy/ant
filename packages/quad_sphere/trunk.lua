local ecs = ...
local math3d = require "math3d"
local constant  = require "constant"
local bgfx      = require "bgfx"

local tt = ecs.transform "trunk_transform"
function tt.process_entity(e)
    e._trunk = {
        cover_tiles = {}
    }
end

local tbt = ecs.transform "trunk_bounding_transform"
function tbt.process_entity(e)
    e._bounding.aabb = math3d.ref(math3d.aabb())
end

local tmt = ecs.transform "trunk_mesh_transform"

local vblayout = constant.vb_layout

function tmt.process_entity(e)
    local rc = e._rendercache
    --rc.ib = constant.trunk_ib.buffer
    local vn = constant.tiles_pre_trunk * 4
    local l = e.ismask and vblayout.mask or vblayout.cover
    rc.vb = {
        start = 0,
        num = vn,
        handles = {
            bgfx.create_dynamic_vertex_buffer(vn, l.handle, "a"),
        }
    }
    rc.ib = {
        start = 0,
        num = 0,
        handle = nil,
    }
end