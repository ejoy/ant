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

if not ENABLE_SHADOW then
	renderutil.default_system(psa_sys, 	"init", "entity_init", "entity_remove", "after_scene_update")
	return
end

function psa_sys:init()
    world:create_entity {
        policy = {
            "ant.general|name",
            "ant.scene|bounding"
        },
        data = {
            name = "pack_scene_aabb",
            pack_scene_aabb = true,
        }
    }
end

local dirty

function psa_sys:entity_init()
    dirty = w:first "INIT scene bounding"
end

function psa_sys:entity_remove()
    if not dirty then
        dirty = w:first "REMOVED scene bounding" 
    end
end

function psa_sys:after_scene_update()
    if not dirty then
        dirty = w:first "scene_changed scene bounding" 
    end
    if dirty then
        local psae = w:first "pack_scene_aabb bounding:update"
        local scene_aabb = math3d.aabb(math3d.vector(0, 0, 0), math3d.vector(0, 0, 0))
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
        local update_aabb = math3d.mark(scene_aabb)
        math3d.unmark(psae.bounding.scene_aabb)
        psae.bounding.scene_aabb = update_aabb
        psae.bounding.aabb       = update_aabb
        w:submit(psae)
        dirty = false
    end
end

