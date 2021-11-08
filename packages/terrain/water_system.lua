local ecs   = ...
local world = ecs.world
local w     = world.w

local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr

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
            local nl = (ih-1)*vn_w+(iw-1)
            local v0, v1, v2, v3 = iw-1, nl, nl+1, iw
            m[idx*s] = fmt:pack(v0, v1, v2, v2, v3, v0)
        end
    end

    return {
        start = 0,
        num = gw * gh * 6,
        bgfx.create_index_buffer(m, "d")
    }
end

local function gen_water_grid_mesh(gw, gh, unit, height)
    local h = height or 0.0
    h = h * unit
    local s = gw*gh*layout.stride
    local m = bgfx.memory_buffer(s)

    --vertex number == (gw+1)*(gh+1)
    for ih=0, gh do
        for iw=0, gw do
            local idx = ih*gw+iw
            local midx= idx*s
            m[midx] = layoutfmt:pack(iw, h, ih)
        end
    end
    return {
        vb = {
            start = 0,
            num = (gw+1)*(gh+1),
            {
                handle = bgfx.create_vertex_buffer(m, layout.handle),
            }
        },
        ib = create_indices_buffer(gw, gh),
    }
end

function water_sys:component_init()
    for e in w:select "INIT water:int simplemesh:out" do
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

function water_sys:data_changed()
    local found
    for e in w:select "light:in" do
        local l = e.light
        if l.type == "directional" then
            local d = iom.get_direction(e)
            local dir = directionlight_info.dir
            dir[1], dir[2], dir[3] = math3d.index(d, 1, 2, 3)
            dir[4] = ilight.intensity(e)
            directionlight_info.color = ilight.color(e)
            found = true
            break
        end
    end

    if found then
        local dir, color = directionlight_info.dir, directionlight_info.color
        for e in w:select "water:in render_object:in" do
            imaterial.set_property_directly(e, "u_directional_light_dir", dir)
            imaterial.set_property_directly(e, "u_direciontal_light_color", color)
        end
    end
end
