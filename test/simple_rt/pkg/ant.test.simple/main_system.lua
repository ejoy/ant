local ecs = ...
local world = ecs.world
local w = world.w

local icamera = ecs.require "ant.camera|camera"
local math3d = require "math3d"
local widget = ecs.require "widget"
local util      = ecs.require "ant.render|postprocess.util"
local queuemgr  = ecs.require "ant.render|queue_mgr"
local irq       = ecs.require "ant.render|renderqueue"
local imesh     = ecs.require "ant.asset|mesh"
local hwi       = import_package "ant.hwi"
local irender   = ecs.require "ant.render|render"
local mu        = import_package "ant.math".util
local iviewport = ecs.require "ant.render|viewport.state"
local renderpkg = import_package "ant.render"
local ivm		= ecs.require "ant.render|visible_mask"
local fbmgr     = renderpkg.fbmgr

local test_viewid = hwi.viewid_generate("test_queue", "main_view")

local m = ecs.system "main_system"

local default_clear_state = {
	depth = 0.0,
	clear = "CD",
}

local view_ratio = {
    x = 0.5, y = 0.0, w = 0.5, h = 0.5,
}

local prefab

local function rect_from_ratio(rc, ratio)
    return {
        x = math.floor(rc.x + ratio.x * rc.w),
        y = math.floor(rc.y + ratio.y * rc.h),
        w = math.max(1, math.floor(rc.w * ratio.w)),
        h = math.max(1, math.floor(rc.h * ratio.h)),
    }
end

local queuename = "test_queue"

local function register_queue()
    queuemgr.register_queue(queuename)
    RENDER_ARG = irender.pack_render_arg(queuename, test_viewid)
    w:register{name = queuename}
end

function m:init()
    register_queue()
end

function m:entity_init()
    for e in w:select "INIT main_queue camera_ref:in render_target:in" do
        local vr = iviewport.device_viewrect
        local view_rect = rect_from_ratio(vr, view_ratio)
        world:create_entity {
            policy = {
                "ant.render|render_queue",
            },
            data = {
                render_target       = {
                    viewid		        = hwi.viewid_get(queuename),
                    clear_state	        = {clear = ""},
                    view_rect	        = view_rect,
                    fb_idx		        = fbmgr.get_fb_idx(hwi.viewid_get "main_view"),
                },
                camera_ref          = assert(e.camera_ref),
                [queuename]	        = true,
                queue_name			= queuename,
                submit_queue		= true,
                visible 			= true,
            }
        }
    end
end

local test_entities = {}

local function create_scene(is_test)

    local light = world:create_instance {
        prefab = "/pkg/ant.test.simple/resource/light.prefab",
        on_ready = function (instance)
            if is_test then
                for _, eid in ipairs(instance.tag["*"]) do
                    local e <close> = world:entity(eid)
                    w:extend(e, "render_object?in")
                    if e.render_object then
                        --test_entities[#test_entities+1] = eid
                    end
                end
            end
        end
    }

    local plane = world:create_entity{
		policy = {
			"ant.render|render",
		},
		data = {
			scene 		= {
				s = {250, 1, 250},
            },
			material 	= "/pkg/ant.resources/materials/mesh_shadow.material",
			visible     = true,
            visible_masks = is_test and "" or nil,
			mesh		= "plane.primitive",
		}
	}

    prefab = world:create_instance {
        prefab = is_test and "/pkg/ant.test.simple/resource/miner/miner.gltf/test.prefab" or "/pkg/ant.test.simple/resource/miner/miner.gltf/mesh.prefab",
        on_ready = function (instance)
            local main_queue = w:first "main_queue camera_ref:in"
            local main_camera <close> = world:entity(main_queue.camera_ref, "camera:in")
            local dir = math3d.vector(0, -1, 1)
            if not icamera.focus_prefab(main_camera, prefab.tag['*'], dir) then
                error "aabb not found"
            end
            if is_test then
                for _, eid in ipairs(instance.tag["*"]) do
                    local e <close> = world:entity(eid)
                    w:extend(e, "render_object?in")
                    if e.render_object then
                        test_entities[#test_entities+1] = eid
                    end
                end
            end
        end
    }

    if is_test then
        --test_entities[#test_entities+1] = plane
    end
end

function m:init_world()
    -- light is unique

    create_scene()
    create_scene(true)
end

local vr_mb = world:sub{"view_rect_changed", "main_queue"}

function m:camera_changed()
    for _, _, _ in vr_mb:unpack() do
        irq.set_view_rect(queuename, rect_from_ratio(iviewport.device_viewrect, view_ratio))
        break
    end
end

function m:render_submit()
    for _, eid in ipairs(test_entities) do
        irender.draw(RENDER_ARG, eid) 
    end
end