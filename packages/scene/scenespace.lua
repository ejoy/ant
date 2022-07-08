local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"


local s = ecs.system "scenespace_system"

local function inherit_state(r, pr)
	if r.fx == nil then
		r.fx = pr.fx
	end
	if r.material == nil then
		r.material = pr.material
	end
end

local function update_render_object(ro, scene)
	if ro then
		ro.worldmat = scene.worldmat
		if scene.parent ~= 0 then
			local parent = world:entity(scene.parent)
			if parent then
				local pr = parent.render_object
				if pr then
					inherit_state(ro, pr)
				end
			else
				error "Unexpected Error."
			end
		end
	end
end

local function init_scene_aabb(scene, bounding)
    if bounding then
        scene.aabb = math3d.mark(bounding.aabb)
        scene.scene_aabb = math3d.mark(math3d.aabb())
    end
end

function s:entity_init()
	for v in w:select "INIT scene:in render_object?in scene_needchange?out" do
		local scene = v.scene
		v.scene_needchange = true
		update_render_object(v.render_object, scene)
	end
    for v in w:select "INIT mesh:in scene:update" do
        init_scene_aabb(v.scene, v.mesh.bounding)
    end
    for v in w:select "INIT simplemesh:in scene:update" do
        init_scene_aabb(v.scene, v.simplemesh.bounding)
    end
    --TODO: should move to render package
    for v in w:select "INIT scene:in render_object:in" do
        v.render_object.aabb = v.scene.scene_aabb
    end
end

function s:scene_update()
	for e in w:select "scene_changed scene:in render_object:in" do
		e.render_object.worldmat = e.scene.worldmat
        e.render_object.aabb = e.scene.scene_aabb
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