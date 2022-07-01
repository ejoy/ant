local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"

local mc = import_package "ant.math".constant

local s = ecs.system "scenespace_system"

local function inherit_state(r, pr)
	if r.fx == nil then
		r.fx = pr.fx
	end
	if r.material == nil then
		r.material = pr.material
	end
end

local function update_aabb(scene)
	if scene.aabb ~= mc.NULL then
		math3d.unmark(scene.scene_aabb)
		scene.scene_aabb = math3d.mark(math3d.aabb_transform(scene.worldmat, scene.aabb))
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

function s:entity_init()
	for v in w:select "INIT scene:in render_object?in scene_changed?out" do
		local scene = v.scene
		v.scene_changed = true
		update_render_object(v.render_object, scene)
	end
end

local function update_scene_obj(scene, parent)
	math3d.unmark(scene.worldmat)
	local mat = math3d.mul(scene.mat, math3d.matrix(scene))
	scene.worldmat = math3d.mark(parent and math3d.mul(parent.worldmat, mat) or mat)
	update_aabb(scene)
end

local evSceneChanged = world:sub {"scene_changed"}

function s:scene_init()
	for _, eid in evSceneChanged:unpack() do
		local e = world:entity(eid)
		if e then
			e.scene_changed = true
		end
	end
end

--function s:scene_changed()
--	for v in w:select "scene_update scene:in scene_changed?out" do
--		local scene = v.scene
--		if scene.parent ~= 0 then
--			local parent = world:entity(scene.parent)
--			if parent then
--				assert(parent.scene_update)
--				if parent.scene_changed then
--					v.scene_changed = true
--				end
--			else
--				error "Unexpected Error."
--			end
--		end
--	end
--end

function s:scene_update()
	for e in w:select "scene_changed scene:update" do
		local scene = e.scene
		local parent = scene.parent ~= 0 and world:entity(scene.parent).scene or nil
		update_scene_obj(scene, parent)
	end
	for e in w:select "scene_changed scene:in render_object:in" do
		e.render_object.worldmat = e.scene.worldmat
        e.render_object.aabb = e.scene.scene_aabb
	end
end

local function hasSceneRemove()
	for _ in w:select "REMOVED scene" do
		return true
	end
end

function s:scene_remove()
	w:clear "scene_changed"
	if hasSceneRemove() then
		for v in w:select "scene:in id:in REMOVED?in" do
			local scene = v.scene
			if scene.parent ~= 0 then
				local parent = world:entity(scene.parent)
				if parent then
					if parent.REMOVED then
						w:remove(v)
					end
				else
					error "Unexpected Error."
				end
			end
		end
	end
end

function ecs.method.init_scene(eid)
	local e = world:entity(eid)
	e.scene_changed = true
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