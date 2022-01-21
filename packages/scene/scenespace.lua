local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"
local mathpkg = import_package "ant.math"
local mu = mathpkg.util

----scenespace_system----
local s = ecs.system "scenespace_system"

local evParentChanged = world:sub {"parent_changed"}

local function inherit_render_object(r, pr)
	if r.fx == nil then
		r.fx = pr.fx
	end
	if r.state == nil then
		r.state = pr.state
	end
	if r.properties == nil then
		r.properties = pr.properties
	end
	local pstate = pr.entity_state
	if pstate then
		local MASK <const> = (1 << 32) - 1
		local state = r.entity_state or 0
		r.entity_state = ((state>>32) | state | pstate) & MASK
	end
end

local current_changed = 1
local current_sceneid = 0

local function new_sceneid()
	current_sceneid = current_sceneid + 1
	return current_sceneid
end

local function update_worldmat_noparent(node)
	local srt = node.srt
	local wm = srt and math3d.matrix(srt) or nil

	local slotmat = node.slot_matrix
	if slotmat then
		wm = wm and math3d.mul(slotmat, wm) or slotmat
	end
	node._worldmat = wm
end

local function update_worldmat(node, parent)
	if parent.changed > node.changed then
		node.changed = parent.changed
	end
	update_worldmat_noparent(node)
	if parent._worldmat then
		node._worldmat = node._worldmat and math3d.mul(parent._worldmat, node._worldmat) or parent._worldmat
	end
end

local function update_aabb(node)
	if node._worldmat == nil or node.aabb == nil then
		node._aabb = nil
	else
		node._aabb = math3d.aabb_transform(node._worldmat, node.aabb)
	end
end

local function isValidReference(reference)
    assert(reference[2] == 1, "Not a reference")
    return reference[1] ~= nil
end

function s:entity_init()
	local needsync = false
	for v in w:select "INIT scene:in scene_sorted?new" do
		local scene = v.scene
		
		if scene.srt then
			scene.srt = mu.srt_obj(scene.srt)
		end
		if scene.updir then
			scene.updir = math3d.ref(math3d.vector(scene.updir))
		end
		scene.changed = current_changed

		scene.id = new_sceneid()
		v.scene_sorted = true
		needsync = true
	end

	for v in w:select "scene_unsorted scene:in scene_sorted?new" do
		v.scene_sorted = true
		v.scene.changed = current_changed
	end
	w:clear "scene_unsorted"

	for _, e, parent in evParentChanged:unpack() do
		if isValidReference(e) then
			w:sync("scene:in", e)
			e.scene.changed = current_changed
			if type(parent) == "number" then
				e.scene.parent = parent
			else
				if not parent or not isValidReference(parent) then
					e.scene.parent = nil
				else
					w:sync("scene:in", parent)
					e.scene.parent = parent.scene.id
				end
			end
			needsync = true
		end
	end

	if needsync then
		local cache = {}
		for v in w:select "scene_sorted scene:in render_object?in INIT?in" do
			local scene = v.scene
			if scene.parent == nil then
				cache[scene.id] = v.render_object or false
			else
				local parent = cache[scene.parent]
				if parent ~= nil then
					cache[scene.id] = v.render_object or false
					if v.INIT then
						local r = v.render_object
						local pr = cache[scene.parent]
						if r and pr then
							inherit_render_object(r, pr)
						end
					end
				else
					v.scene_sorted = false -- yield
				end
			end
		end
	end
end

function s:update_hierarchy()
end

local evSceneChanged = world:sub {"scene_changed"}
function s:update_transform()
	for _, e in evSceneChanged:unpack() do
		if e then
			w:sync("scene:in", e)
			e.scene.changed = current_changed
		end
	end

	local cache = {}
	for v in w:select "scene_sorted scene:in scene_changed?out" do
		local scene = v.scene
		if scene.parent == nil then
			cache[scene.id] = scene
			update_worldmat_noparent(scene)
			update_aabb(scene)
			if scene.changed == current_changed then
				v.scene_changed = true
			end
		else
			local parent = cache[scene.parent]
			if parent then
				cache[scene.id] = scene
				update_worldmat(scene, parent)
				update_aabb(scene)
				if scene.changed == current_changed then
					v.scene_changed = true
				end
			else
				v.scene_sorted = false -- yield
			end
		end
	end
	for v in w:select "render_object:in scene:in" do
		local r, n = v.render_object, v.scene
		r.aabb = n._aabb
		r.worldmat = n._worldmat
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
		local cache = {}
		for v in w:select "scene_sorted scene:in REMOVED?in" do
			local scene = v.scene
			if scene.parent == nil then
				scene.REMOVED = v.REMOVED
				cache[scene.id] = scene
			else
				local parent = cache[scene.parent]
				if parent then
					cache[scene.id] = scene
					if v.REMOVED then
						scene.REMOVED = true
					elseif parent.REMOVED then
						scene.REMOVED = true
						w:remove(v)
					end
				else
					v.scene_sorted = false -- yield
				end
			end
		end
	end
end

function ecs.method.init_scene(e)
	e.scene_unsorted = true
	w:sync("scene:in scene_unsorted?out", e)
	local scene = e.scene
	scene.id = new_sceneid()
	if scene.srt then
		scene.srt = mu.srt_obj(scene.srt)
	end
	if scene.updir then
		scene.updir = math3d.ref(math3d.vector(scene.updir))
	end
end

function ecs.method.set_parent(e, parent)
	world:pub {"parent_changed", e, parent}
end
