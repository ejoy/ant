local ecs   = ...
local world = ecs.world
local w     = world.w
local queuemgr	= ecs.require "queue_mgr"
local psa_sys = ecs.system "pack_scene_aabb_system"
local math3d    = require "math3d"
local setting	= import_package "ant.settings"
local ENABLE_SHADOW<const> = setting:get "graphic/shadow/enable"
local renderutil= require "util"
local mc = import_package "ant.math".constant
local zero_aabb = math3d.ref(math3d.aabb(math3d.vector(0, 0, 0), math3d.vector(0, 0, 0)))
if not ENABLE_SHADOW then
	renderutil.default_system(psa_sys, 	"init", "data_changed")
	return
end

function psa_sys:init()
    world:create_entity {
        policy = {
            "ant.general|name",
        },
        data = {
            name = "pack_scene_aabb",
            pack_scene_aabb = true
        }
    }
end

function psa_sys:data_changed()
    for psae in w:select "pack_scene_aabb:update" do
        local scene_aabb = zero_aabb
        local mask = assert(queuemgr.queue_mask("main_queue"))
        for e in w:select "render_object_visible bounding:in render_object:in" do
            if (mask & e.render_object.visible_masks) and (mask & e.render_object.cull_masks) then
                if e.bounding.scene_aabb and e.bounding.scene_aabb ~= mc.NULL then
                    scene_aabb = math3d.aabb_merge(scene_aabb, e.bounding.scene_aabb) 
                end
            end
        end
        for e in w:select "hitch_visible bounding:in hitch:in" do
            if (mask & e.hitch.visible_masks) and (mask & e.hitch.cull_masks) then
                if e.bounding.scene_aabb and e.bounding.scene_aabb ~= mc.NULL then
                    scene_aabb = math3d.aabb_merge(scene_aabb, e.bounding.scene_aabb) 
                end
            end
        end
        psae.pack_scene_aabb = math3d.ref(scene_aabb)       
    end
end

