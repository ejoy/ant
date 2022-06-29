local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"
local mc = import_package "ant.math".constant

----scenespace_system----
local s = ecs.system "scenespace_system"

local function inherit_state(r, pr)
	if r.fx == nil then
		r.fx = pr.fx
	end
	if r.material == nil then
		r.material = pr.material
	end

	--TODO: need rewrite
	-- local pstate = pr.filter_state
	-- if pstate then
	-- 	local MASK <const> = (1 << 32) - 1
	-- 	local state = r.filter_state or 0
	-- 	r.filter_state = ((state>>32) | state | pstate) & MASK
	-- end
end

local function update_aabb(scene)
	if scene.aabb then
		scene.scene_aabb.m = math3d.aabb_transform(scene.worldmat, scene.aabb)
	end
end

local function srt_obj(srt)
	local s, r, t = srt.s, srt.r, srt.t
	if type(s) == "number" then
		s = {s, s, s}
	end
	srt.s = math3d.mark(s and math3d.vector(s) or mc.ONE)
	srt.r = math3d.mark(r and math3d.quaternion(r) or mc.IDENTITY_QUAT)
	srt.t = math3d.mark(t and math3d.vector(t) or mc.ZERO_PT)
end

local function init_scene(scene)
	srt_obj(scene)
	if scene.updir then
		scene.updir = math3d.ref(math3d.vector(scene.updir))
	end
	scene.worldmat = math3d.ref(mc.IDENTITY_MAT)
end

local function update_render_object(ro, scene)
	if ro then
		ro.worldmat = scene.worldmat
		if scene.parent then
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
		init_scene(scene)
		update_render_object(v.render_object, scene)
	end
end

function s:update_hierarchy()
end

local function update_scene_obj(scene, parent)
	local srt = math3d.matrix(scene)
	scene.worldmat.m = parent and math3d.mul(parent.worldmat, srt) or srt
	update_aabb(scene)
end

local evSceneChanged = world:sub {"scene_changed"}
function s:update_transform()
	for _, eid in evSceneChanged:unpack() do
		world:entity(eid).scene_changed = true
	end

	for v in w:select "scene_update scene:in id:in scene_changed?out" do
		local scene = v.scene
		if scene.parent then
			local parent = world:entity(scene.parent)
			if parent then
				assert(parent.scene_update)
				if parent.scene_changed then
					v.scene_changed = true
				end
			else
				error "Unexpected Error."
			end
		end
	end

	for e in w:select "scene_changed scene:in" do
		local scene = e.scene
		local parent = scene.parent and world:entity(scene.parent).scene or nil
		update_scene_obj(scene, parent)
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
		for v in w:select "scene:in REMOVED?in" do
			local scene = v.scene
			if scene.parent == nil then
				scene.REMOVED = v.REMOVED
			else
				local parent = world:entity(scene.parent)
				if parent then
					if v.REMOVED then
						scene.REMOVED = true
					elseif parent.REMOVED then
						scene.REMOVED = true
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
	init_scene(e.scene)
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