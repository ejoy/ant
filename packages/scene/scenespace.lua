local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"
local mathpkg = import_package "ant.math"
local mu, mc = mathpkg.util, mathpkg.constant

----scenespace_system----
local s = ecs.system "scenespace_system"

local evParentChanged = world:sub {"parent_changed"}

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

local current_changed = 1

local function update_worldmat_noparent(scene)
	local srt = scene.srt
	scene.worldmat.m = srt and math3d.matrix(srt) or mc.IDENTITY_MAT
end

local function update_worldmat(scene, parent)
	if parent.changed > scene.changed then
		scene.changed = parent.changed
	end
	update_worldmat_noparent(scene)
	if parent.worldmat then
		scene.worldmat.m = math3d.mul(parent.worldmat, scene.worldmat)
	end
end

local function update_aabb(scene)
	if scene.aabb then
		scene.scene_aabb.m = math3d.aabb_transform(scene.worldmat, scene.aabb)
	end
end

local function init_scene(scene)
	if scene.srt then
		scene.srt = mu.srt_obj(scene.srt)
	end
	if scene.updir then
		scene.updir = math3d.ref(math3d.vector(scene.updir))
	end
	scene.worldmat = math3d.ref(mc.IDENTITY_MAT)
end

function s:entity_init()
	local needsync = false
	for v in w:select "INIT scene:in render_object?in" do
		local scene = v.scene
		scene.changed = current_changed
		init_scene(scene)
		if v.render_object then
			v.render_object.worldmat = v.scene.worldmat
		end
		needsync = true
	end
	for v in w:select "scene_needsync scene:in" do
		v.scene.changed = current_changed
		needsync = true
	end
	w:clear "scene_needsync"

	if needsync then
		local visited = {}
		for v in w:select "scene:in id:in render_object?in INIT?in" do
			local scene = v.scene
			if scene.parent == nil then
				visited[v.id] = true
			else
				local parent = world:entity(scene.parent)
				if parent then
					if visited[scene.parent] then
						visited[v.id] = true
						if v.INIT then
							local r = v.render_object
							local pr = parent.render_object
							if r and pr then
								inherit_state(r, pr)
							end
						end
					else
						error "Unexpected Error."
					end
				else
					error "Unexpected Error."
				end
			end
		end
	end
end

function s:update_hierarchy()
end

local function update_scene_obj(scene, parent)
	if parent == nil then
		update_worldmat_noparent(scene)
	else
		update_worldmat(scene, parent)
	end
	update_aabb(scene)
end

local evSceneChanged = world:sub {"scene_changed"}
function s:update_transform()
	local scene_need_update
	for _, eid in evSceneChanged:unpack() do
		local e = world:entity(eid)
		e.scene.changed = current_changed
		scene_need_update = true
	end

	if scene_need_update then
		local visited = {}
		for v in w:select "scene_update scene:in id:in scene_changed?out" do
			local scene = v.scene
			if scene.parent == nil then
				visited[v.id] = true
				if scene.changed == current_changed then
					v.scene_changed = true
				end
			else
				local parent = world:entity(scene.parent)
				if parent then
					assert(parent.scene_update)
					if visited[scene.parent] then
						visited[v.id] = true
						if scene.changed == current_changed or parent.scene_changed then
							v.scene_changed = true
						end
					else
						error "Unexpected Error."
					end
				else
					error "Unexpected Error."
				end
			end
		end
	end

	for e in w:select "scene_changed scene:in" do
		local scene = e.scene
		local parent = scene.parent and world:entity(scene.parent).scene or nil
		update_scene_obj(scene, parent)
	end
	current_changed = current_changed + 1
end

local function hasSceneRemove()
	for _ in w:select "REMOVED scene" do
		return true
	end
end

function s:scene_remove()
	w:clear "scene_changed"
	if hasSceneRemove() then
		local visited = {}
		for v in w:select "scene:in id:in REMOVED?in" do
			local scene = v.scene
			if scene.parent == nil then
				scene.REMOVED = v.REMOVED
				visited[v.id] = true
			else
				local parent = world:entity(scene.parent)
				if parent then
					if visited[scene.parent] then
						visited[v.id] = true
						if v.REMOVED then
							scene.REMOVED = true
						elseif parent.REMOVED then
							scene.REMOVED = true
							w:remove(v)
						end
					else
						error "Unexpected Error."
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
	e.scene_needsync = true
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