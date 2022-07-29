local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"


local s = ecs.system "scenespace_system"

local function inherit_state(r, pro)
	if r.fx == nil then
		r.fx = pro.fx
	end
	if r.material == nil then
		r.material = pro.material
	end
end

local function update_render_object(ro, scene)
	if ro then
		ro.worldmat = scene.worldmat
		if scene.parent ~= 0 then
			local parent = world:entity(scene.parent)
			if parent then
				local pro = parent.render_object
				if pro then
					inherit_state(ro, pro)
				end
			else
				error "Unexpected Error."
			end
		end
	end
end

local function update_render_obj(ro, scene)
	if ro then
		ro.worldmat = scene.worldmat
	end
end

local function init_scene_aabb(scene, bounding)
    if bounding then
        scene.aabb = math3d.mark(bounding.aabb)
        scene.scene_aabb = math3d.mark(math3d.aabb())
    end
end

function s:entity_init()
	for v in w:select "INIT scene mesh?in simplemesh?in scene_needchange?out" do
		local m = v.mesh or v.simplemesh
		if m then
			init_scene_aabb(v.scene, m.bounding)
		end
		v.scene_needchange = true
	end
end

function s:scene_update()
	for e in w:select "scene_changed scene:in render_object:update" do
		e.render_object.worldmat = e.scene.worldmat
	end
end

function ecs.method.set_parent(e, parent)
	world:pub {"parent_changed", e, parent}
end

local sceneupdate_sys = ecs.system "scene_update_system"
function sceneupdate_sys:init()
	ecs.group(0):enable "scene_update"
	ecs.group_flush()
end

local g_sys = ecs.system "group_system"
function g_sys:start_frame()
	ecs.group_flush()
end

local static_sceneobj = ecs.system "standalone_scene_object_system"
function static_sceneobj:entity_init()
	for e in w:select "INIT standalone_scene_object scene scene_update?out standalone_scene_object_update?out" do
		e.scene_update = true
		e.standalone_scene_object_update = true
	end
end

function static_sceneobj:end_frame()
	for e in w:select "standalone_scene_object_update standalone_scene_object scene_update?out" do
		e.scene_update = nil
	end
	w:clear "standalone_scene_object_update"
end