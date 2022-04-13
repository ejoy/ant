local ecs   = ...
local world = ecs.world
local w     = world.w

local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr
local fbmgr     = renderpkg.fbmgr
local viewidmgr = renderpkg.viewidmgr
local samplerutil=renderpkg.sampler

local ilight    = ecs.import.interface "ant.render|ilight"
local iom       = ecs.import.interface "ant.objcontroller|iobj_motion"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local imesh     = ecs.import.interface "ant.asset|imesh"
local ientity   = ecs.import.interface "ant.render|ientity"
local irender   = ecs.import.interface "ant.render|irender"

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

local copy_scene_viewid = viewidmgr.get "copy_scene"

local function create_fb(mq_fbidx)
    local clrrb = fbmgr.get_rb(mq_fbidx, 1)
    return fbmgr.create{
        rbidx=fbmgr.create_rb{
            w = clrrb.w, h = clrrb.h,
            layers = clrrb.layers, 
            format = clrrb.format,
            mipmap = true,
            flags = samplerutil.sampler_flag {
                RT="RT_ON",
                MIN="LINEAR",
                MAG="LINEAR",
                U="CLAMP",
                V="CLAMP",
            },
        }
    }
end


function water_sys:init_world()
    local mq = w:singleton("main_queue", "render_target:in")
    local mqrt = mq.render_target
    local vr = mqrt.view_rect
    w:register{name="copy_scene_queue"}
    ecs.create_entity{
        policy = {
            "ant.render|postprocess_queue",
            "ant.render|watch_screen_buffer",
            "ant.general|name",
        },
        data = {
            name = "copy_scene_queue",
            render_target = {
                viewid = copy_scene_viewid,
                view_rect = {x=vr.x, y=vr.y, w=vr.w, h=vr.h, ratio=vr.ratio},
                view_mode = "",
                clear_state = {clear = ""},
                fb_idx = create_fb(mqrt.fb_idx),
            },
            queue_name = "copy_scene",
            watch_screen_buffer = true,
            copy_scene_queue = true,
        }
    }

    w:register {name="copy_scene_drawer"}
    ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            simplemesh  = imesh.init_mesh(ientity.fullquad_mesh()),
            material    = "/pkg/ant.resources/materials/texquad.material",
            scene       = {srt={}},
            filter_state= "",
            name        = "copy_scene_drawer",
            copy_scene_drawer = true
        }
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

local scene_tex = {
    stage = 5,
    texture = {handle=nil}
}

local scene_depth_tex = {
    stage = 6,
    texture = {handle=nil}
}

local function queue_rb_handle(qn, rbidx)
    local q = w:singleton(qn, "render_target:in")
    return fbmgr.get_rb(q.render_target.fb_idx, rbidx).handle
end

function water_sys:data_changed()
    for e in w:select "directional_light light:in" do
        local d = iom.get_direction(e)
        local color = ilight.color(e)
        local intensity = ilight.intensity(e)
        color[4] = intensity

        scene_tex.texture.handle = queue_rb_handle("copy_scene_queue", 1)
        scene_depth_tex.texture.handle = queue_rb_handle("main_queue", -1)  -- -1 for last rb index, here is depth buffer
        for we in w:select "water:in render_object:in" do
            imaterial.set_property(we, "u_directional_light_dir",   d)
            imaterial.set_property(we, "u_direciontal_light_color", color)
            imaterial.set_property(we, "s_scene",                   scene_tex)
            imaterial.set_property(we, "s_scene_depth",             scene_depth_tex)
        end
        break
    end
end

local copy_tex = {
    stage = 0,
    texture = {handle=nil}
}

function water_sys:render_submit()
    local csq = w:singleton("copy_scene_queue", "render_target:in")
    local csq_rt = csq.render_target

    copy_tex.texture.handle = queue_rb_handle("main_queue", 1)

    local cs_obj = w:singleton("copy_scene_drawer", "render_object:in")
    local ro = cs_obj.render_object
    imaterial.set_property_directly(ro.properties, "s_tex", copy_tex)
    irender.draw(csq_rt.viewid, ro)
end