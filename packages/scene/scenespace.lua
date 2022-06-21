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

local function update_worldmat_noparent(node)
	local srt = node.srt
	node._worldmat.m = srt and math3d.matrix(srt) or mc.IDENTITY_MAT
end

local function update_worldmat(node, parent)
	if parent.changed > node.changed then
		node.changed = parent.changed
	end
	update_worldmat_noparent(node)
	if parent._worldmat then
		node._worldmat.m = math3d.mul(parent._worldmat, node._worldmat)
	end
end

local function update_aabb(node)
	if node.aabb then
		node._aabb.m = math3d.aabb_transform(node._worldmat, node.aabb)
	end
end

local function init_scene(scene)
	if scene.srt then
		scene.srt = mu.srt_obj(scene.srt)
	end
	if scene.updir then
		scene.updir = math3d.ref(math3d.vector(scene.updir))
	end
	scene._worldmat = math3d.ref(mc.IDENTITY_MAT)
	if scene.aabb then
		scene._aabb = math3d.ref(math3d.aabb())
	end
end

function s:entity_init()
	local needsync = false
	for v in w:select "INIT scene:in scene_sorted?new" do
		local scene = v.scene
		scene.changed = current_changed
		init_scene(scene)
		v.scene_sorted = true
		needsync = true
	end

	for v in w:select "scene_unsorted scene:in scene_sorted?new" do
		v.scene_sorted = true
		v.scene.changed = current_changed
	end
	w:clear "scene_unsorted"

	for _, id, parentid in evParentChanged:unpack() do
		local e = world:entity(id)
		if e then
			e.scene.changed = current_changed
			e.scene.parent = parentid
			needsync = true
		end
	end

	if needsync then
		local visited = {}
		for v in w:select "scene_sorted scene:in id:in render_object?in INIT?in" do
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
						v.scene_sorted = false -- yield
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

local evSceneChanged = world:sub {"scene_changed"}
function s:update_transform()
	for _, eid in evSceneChanged:unpack() do
		local e = world:entity(eid)
		e.scene.changed = current_changed
	end

	local visited = {}
	local sorted_scene = {}
	for v in w:select "scene_sorted scene:in id:in scene_changed?out" do
		local scene = v.scene
		if scene.parent == nil then
			visited[v.id] = true
			if scene.changed == current_changed then
				sorted_scene[#sorted_scene+1] = {scene}
				v.scene_changed = true
			end
		else
			local parent = world:entity(scene.parent)
			if parent then
				if visited[scene.parent] then
					visited[v.id] = true
					if scene.changed == current_changed then
						sorted_scene[#sorted_scene+1] = {scene, parent.scene}
						v.scene_changed = true
					end
				else
					v.scene_sorted = false -- yield
				end
			else
				error "Unexpected Error."
			end
		end
	end

	for _, ss in ipairs(sorted_scene) do
		local scene, parent = ss[1], ss[2]
		if parent == nil then
			update_worldmat_noparent(scene)
		else
			update_worldmat(scene, parent)
		end
		update_aabb(scene)
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
		local visited = {}
		for v in w:select "scene_sorted scene:in id:in REMOVED?in" do
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
						v.scene_sorted = false -- yield
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
	e.scene_unsorted = true
	init_scene(e.scene)
end

function ecs.method.set_parent(e, parent)
	world:pub {"parent_changed", e, parent}
end
