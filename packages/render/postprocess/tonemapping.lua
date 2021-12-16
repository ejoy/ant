local ecs   = ...
local world = ecs.world
local w     = world.w

local viewidmgr = require "viewid_mgr"
local sampler   = require "sampler"

local tm_sys    = ecs.system "tonemapping_system"
local ientity   = ecs.import.interface "ant.render|ientity"
local irender   = ecs.import.interface "ant.render|irender"
local irq       = ecs.import.interface "ant.render|irenderqueue"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local imesh     = ecs.import.interface "ant.asset|imesh"
local iexposure = ecs.import.interface "ant.camera|iexposure"

local math3d    = require "math3d"

local tm_viewid<const> = viewidmgr.get "tonemapping"
local tm_materialfile<const> = "/pkg/ant.resources/materials/postprocess/tonemapping.material"
local tm_auto_material, tm_manual_material
local tm_material
local tm_e
function tm_sys:init()
    tm_manual_material  = imaterial.load(tm_materialfile, {EXPOSURE_TYPE=1})
    tm_auto_material    = imaterial.load(tm_materialfile, {EXPOSURE_TYPE=2})
    tm_material = tm_manual_material
    tm_e = ecs.create_entity {
        policy = {
            "ant.general|name",
            "ant.render|simplerender",
        },
        data = {
            name = "tonemapping_render_obj",
            simplemesh = imesh.init_mesh(ientity.quad_mesh()),
            material = tm_materialfile,
            scene = {srt = {},},
            render_object   = {},
            filter_state = "",
            visible = true,
            reference = true
        }
    }
end

local function update_exposure(cref)
    w:sync("exposure:in", cref)
    local expo = cref.exposure
    assert(expo, "invalid camera without 'exposure' component")
    if expo.type == "auto" then
        tm_material = tm_auto_material
    else
        tm_material = tm_manual_material
        assert(expo.type == "manual")
        local ev = iexposure.exposure(cref)
        imaterial.set_property_directly(tm_manual_material.properties, "u_exposure_param", {ev, 0.0, 0.0, 0.0})
    end
end

local cc_mb = world:sub{"main_queue", "camera_changed"}
local exposure_mb

function tm_sys:init_world()
    local vr = irq.view_rect "main_queue"
    ecs.create_entity {
        policy = {
            "ant.render|postprocess_queue",
            "ant.general|name",
        },
        data = {
            render_target = {
                viewid     = tm_viewid,
                view_rect   = {x=vr.x, y=vr.y, w=vr.w, h=vr.h},
                view_mode = "",
                clear_state = {
                    clear = "",
                },
            },
            queue_name = "tonemapping_queue",
            name = "tonemapping_rt_obj",
            tonemapping_queue = true,
        }
    }

    local mcref = irq.main_camera()
    update_exposure(mcref)
    exposure_mb = world:sub{"exposure_changed", mcref}
end

local pp_input0 = {
    stage = 0,
    texture={handle=nil},
}

local function update_properties()
    for msg in cc_mb:each() do
        exposure_mb = world:sub{"exposure_changed", msg[3]}
    end
    for msg in exposure_mb:each() do
        update_exposure(msg[2])
    end

    --TODO: we need something call frame graph, frame graph need two stage: compile and run, with virtual resource
    -- in compile stage, determine which postprocess stage is needed, and connect those virtual resources
    -- render target here, is one of the virtual resource
    local pp = w:singleton("postprocess", "postprocess_input:in")
    local ppi = pp.postprocess_input
    pp_input0.texture.handle = assert(ppi[1].handle)
    imaterial.set_property_directly(tm_material.properties, "s_postprocess_input0", pp_input0)
end

function tm_sys:tonemapping()
    w:sync("render_object:in", tm_e)
    local ro = tm_e.render_object
    update_properties()
    irender.draw(tm_viewid, ro, tm_material)
end