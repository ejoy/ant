local ecs   = ...
local world = ecs.world
local w     = world.w
local mca_sys = ecs.system "main_camera_aabb_system"
local math3d    = require "math3d"
local setting	= import_package "ant.settings"
local ENABLE_SHADOW<const> = setting:get "graphic/shadow/enable"
local renderutil= require "util"

if not ENABLE_SHADOW then
	renderutil.default_system(mca_sys, 	"init", "entity_init", "update_camera")
	return
end

function mca_sys:init()
    world:create_entity {
        policy = {
            "ant.render|main_camera_aabb",
        },
        data = {
            main_camera_aabb = {
                default_update = true
            },
        }
    }
end

function mca_sys:entity_init()
    for e in w:select "INIT main_camera_aabb:update" do
        e.main_camera_aabb.scene_aabb = math3d.marked_aabb() 
    end
end

function mca_sys:update_camera()
    local mcae = w:first "main_camera_aabb:update"
    local mq = w:first "main_queue camera_ref:in"
	local ce <close> = world:entity(mq.camera_ref, "camera_changed?in camera:in scene:in")
    if mcae and mcae.main_camera_aabb.default_update and ce.camera_changed then
		local world_frustum_points = math3d.frustum_points(ce.camera.viewprojmat)
		local camera_min, camera_max = math3d.minmax(world_frustum_points)
		math3d.unmark(mcae.main_camera_aabb.scene_aabb)
		mcae.main_camera_aabb.scene_aabb = math3d.marked_aabb(camera_min, camera_max)
        w:submit(mcae)  
    end
end