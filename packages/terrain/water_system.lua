local ecs   = ...
local world = ecs.world
local w     = world.w

local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr
local fbmgr     = renderpkg.fbmgr

local ilight    = ecs.import.interface "ant.render|light"
local iom       = ecs.import.interface "ant.objcontroller|obj_motion"
local imaterial = ecs.import.interface "ant.asset|imaterial"

local bgfx      = require "bgfx"
local math3d    = require "math3d"

local layout    = declmgr.get "p3"

local water_sys = ecs.system "water_system"
local layoutfmt = "fff"

--[[
    1-----2
    |     |
    0-----3
]]

local function create_indices_buffer(gw, gh)
    local fmt<const> = "IIIIII"
    local s = #fmt * 4
    local m = bgfx.memory_buffer(gw*gh*s)
    local vn_w = gw+1
    for ih=1, gh do
        for iw=1, gw do
            local idx = (ih-1)*gw+iw-1
            local nl = ih*vn_w+(iw-1)
            local v0, v1, v2, v3 = iw-1, nl, nl+1, iw
            m[idx*s+1] = fmt:pack(v0, v1, v2, v2, v3, v0)
        end
    end

    return {
        start = 0,
        num = gw * gh * 6,
        handle = bgfx.create_index_buffer(m, "d")
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
            m[midx]   = layoutfmt:pack(iw, h, ih)
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

function water_sys:component_init()
    for e in w:select "INIT water:in simplemesh:out" do
        local water = e.water
        local gw, gh = water.grid_width, water.grid_height
        local unit = water.unit
        e.simplemesh = gen_water_grid_mesh(gw, gh, unit)
    end
end

function water_sys:entity_init()
    
end

local directionlight_info = {
    dir = {0, 0, 0, 0},
    color = {0, 0, 0, 0},
}

local scene_tex = {
    stage = 5,
    texture = {handle=nil}
}

local scene_depth_tex = {
    stage = 6,
    texture = {handle=nil}
}

function water_sys:data_changed()
    for e in w:select "directional_light light:in" do
        local d = iom.get_direction(e)
        local color = ilight.color(e)
        local intensity = ilight.intensity(e)
        color[4] = intensity
        local mq = w:singleton("main_queue", "render_target:in")
        local mq_fb = fbmgr.get(mq.render_target.fb_idx)
        scene_tex.texture.handle = fbmgr.get_rb(mq_fb[1]).handle
        scene_depth_tex.texture.handle = fbmgr.get_rb(mq_fb[#mq_fb]).handle
        for we in w:select "water:in render_object:in" do
            imaterial.set_property(we, "u_directional_light_dir", d)
            imaterial.set_property(we, "u_direciontal_light_color", color)
            imaterial.set_property(we, "s_scene", scene_tex)
            imaterial.set_property(we, "s_scene_depth", scene_depth_tex)
        end
        break
    end
end
