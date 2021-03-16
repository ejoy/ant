local ecs = ...
local math3d = require "math3d"
local constant  = require "constant"
local bgfx      = require "bgfx"

local tt = ecs.transform "trunk_transform"
function tt.process_entity(e)
    e._trunk = {
        qseid = e.trunk.qseid,
    }
end

local function create_color_uv_handle()
    local uvs = {}
    for i=0, constant.tile_pre_trunk_line do
        local u = i * constant.inv_tile_pre_trunk_line
        for j=0, constant.tile_pre_trunk_line do
            local v = j * constant.inv_tile_pre_trunk_line
            uvs[#uvs+1] = u;    uvs[#uvs+1] = v
            uvs[#uvs+1] = u+1;  uvs[#uvs+1] = v
            uvs[#uvs+1] = u+1;  uvs[#uvs+1] = v+1
            uvs[#uvs+1] = u;    uvs[#uvs+1] = v+1
        end
    end
    return bgfx.create_vertex_buffer(bgfx.memory_buffer("ff", uvs), constant.vb_layout[2].handle)
end

local color_layer_uv_handle = create_color_uv_handle()

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
    rc.vb = {
        start = 0,
        num = vn,
        handles = {
            bgfx.create_dynamic_vertex_buffer(vn, vblayout[1].handle),
            color_layer_uv_handle,
        }
    }
end