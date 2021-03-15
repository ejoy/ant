local ecs = ...

local math3d = require "math3d"
local constant  = require "constant"
local bgfx      = require "bgfx"

local tt = ecs.transform "trunk_transform"
function tt.process_entity(e)
    e._trunk = {
        qseid = e.trunk.qseid,
        mark_uv = e.mark_uv,
    }
end

local tuct = ecs.transform "trunk_uv_transform"
function tuct.process_prefab(e)
    local t = e._trunk
    local qse = world[t.qs_eid]
    local markuv = qse._quad_sphere.mark_uv
    local w, h = markuv.w, markuv.h
    local n = markuv.num
    local s = markuv.size

    local iw, ih = 1.0/w, 1.0/h
    local c = {}

    for i=1, n do
        local u = (i-1) * iw
        local v = (((i-1) * s) // w) * ih
        c[i+0] = u;   c[i+0] = v;
        c[i+1] = u+1; c[i+1] = v;
        c[i+2] = u+1; c[i+2] = v+1;
        c[i+3] = u;   c[i+3] = v+1;

        -- rotate math.pi * 0.5
        local ir90 = n * 8
        c[ir90+i+0] = u+1; c[ir90+i+0] = v;
        c[ir90+i+1] = u+1; c[ir90+i+1] = v+1;
        c[ir90+i+2] = u;   c[ir90+i+2] = v+1;
        c[ir90+i+3] = u;   c[ir90+i+3] = v;

        -- rotate math.pi
        local ir180 = n * 8 * 2
        
        c[ir180+i+0] = u+1; c[ir180+i+0] = v+1;
        c[ir180+i+1] = u;   c[ir180+i+1] = v+1;
        c[ir180+i+2] = u;   c[ir180+i+2] = v;
        c[ir180+i+3] = u+1; c[ir180+i+3] = v;

        -- rotate math.pi * 1.5
        local ir270 = n * 8 * 3

        c[ir270+i+0] = u;   c[ir270+i+0] = v+1;
        c[ir270+i+1] = u;   c[ir270+i+1] = v;
        c[ir270+i+2] = u+1; c[ir270+i+2] = v;
        c[ir270+i+3] = u+1; c[ir270+i+3] = v+1;
    end
    t.mark_uv_coords = c
end

local tlt = ecs.transform "trunk_layer_uv_transform"
function tlt.process_prefab(e)
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
    e._cache_prefab.layer_uv_handle = bgfx.create_vertex_buffer(bgfx.memory_buffer("ff", uvs), constant.vb_layout[2].handle)
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
    local c = e._cache_prefab
    --rc.ib = constant.trunk_ib.buffer
    rc.vb = {
        start = 0,
        num = vn,
        handles = {
            bgfx.create_dynamic_vertex_buffer(vn, vblayout[1].handle),
            c.layer_uv_handle,
        }
    }
end