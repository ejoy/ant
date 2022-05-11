local ecs   = ...
local world = ecs.world
local w     = world.w

local viewidmgr = require "viewid_mgr"

local tm_sys    = ecs.system "tonemapping_system"
local ientity   = ecs.import.interface "ant.render|ientity"
local irender   = ecs.import.interface "ant.render|irender"
local irq       = ecs.import.interface "ant.render|irenderqueue"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local imesh     = ecs.import.interface "ant.asset|imesh"
local iexposure = ecs.import.interface "ant.camera|iexposure"

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
            simplemesh = {vb = {num = 3,}},
            material = tm_materialfile,
            scene = {srt = {},},
            render_object   = {},
            filter_state = "",
            visible = true,
        }
    }
end

function tm_sys:init_world()
    local vp = world.args.viewport
    ecs.create_entity {
        policy = {
            "ant.render|postprocess_queue",
            "ant.general|name",
        },
        data = {
            render_target = {
                viewid     = tm_viewid,
                view_rect   = {x=vp.x, y=vp.y, w=vp.w, h=vp.h},
                view_mode = "",
                clear_state = {
                    clear = "D", --clear z buffer for effect
                    depth = 1
                },
            },
            queue_name = "tonemapping_queue",
            name = "tonemapping_rt_obj",
            tonemapping_queue = true,
        }
    }
end

local vp_changed_mb = world:sub{"world_viewport_changed"}

function tm_sys:data_changed()
    for _, vp in vp_changed_mb:unpack() do
        irq.set_view_rect("tonemapping_queue", vp)
        break
    end
end

local function update_properties()
    --TODO: we need something call frame graph, frame graph need two stage: compile and run, with virtual resource
    -- in compile stage, determine which postprocess stage is needed, and connect those virtual resources
    -- render target here, is one of the virtual resource
    local pp = w:singleton("postprocess", "postprocess_input:in")
    local ppi = pp.postprocess_input
    tm_material.material.s_scene_color = assert(ppi.scene_color_handle)
    tm_material.material.s_bloom_color = ppi.bloom_color_handle
end

function tm_sys:tonemapping()
    local e = world:entity(tm_e)
    local ro = e.render_object
    update_properties()
    irender.draw(tm_viewid, ro, tm_material)
end