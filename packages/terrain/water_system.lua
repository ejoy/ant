local ecs   = ...
local world = ecs.world
local w     = world.w

local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr
local fbmgr     = renderpkg.fbmgr
local viewidmgr = renderpkg.viewidmgr

local imaterial = ecs.import.interface "ant.asset|imaterial"
local irender   = ecs.import.interface "ant.render|irender"

local bgfx      = require "bgfx"

local layout    = declmgr.get "p3|t2"

local water_sys = ecs.system "water_system"
local layoutfmt<const> = "fffff"    --p3|t2

--[[
    1-----2
    |     |
    0-----3
]]

local function create_indices_buffer(gw, gh)
    return {
        start = 0,
        num = gw * gh * 6,
        handle = irender.quad_ib(),
    }
end

local function gen_water_grid_mesh(gw, gh, unit, height)
    local h = height or 0.0
    h = h * unit
    local vw, vh = gw+1, gh+1
    local stride = layout.stride
    local s = vw*vh*stride
    local m = bgfx.memory_buffer(s)

    --vertex number == (gw+1)*(gh+1)
    for ih=0, gh do
        for iw=0, gw do
            local vi = ih*vw+iw
            local midx= vi*stride+1
            local u, v = iw/gw, ih/gh
            m[midx]   = layoutfmt:pack(iw, h, ih, u, v)
        end
    end
    return {
        vb = {
            start = 0,
            num = vw * vh,
            {
                handle = bgfx.create_vertex_buffer(m, layout.handle),
            }
        },
        ib = create_indices_buffer(gw, gh),
    }
end

local ppo_viewid<const> = viewidmgr.get "postprocess_obj"
function water_sys:component_init()
    for e in w:select "INIT water:in simplemesh:out" do
        local water = e.water
        local gw, gh = water.grid_width, water.grid_height
        local unit = water.unit
        e.simplemesh = gen_water_grid_mesh(gw, gh, unit)
    end
end

local function queue_rb_handle(qn, idx)
    local q = w:singleton(qn, "render_target:in")
    local fb = fbmgr.get(q.render_target.fb_idx)
    return fb[idx or #fb].handle
end

function water_sys:render_submit()
    local sdh = queue_rb_handle "scene_depth_queue"
    for we in w:select "water:in render_object:in" do
        imaterial.set_property(we, "s_scene_depth", sdh)
        irender.draw(ppo_viewid, we.render_object)
    end
end