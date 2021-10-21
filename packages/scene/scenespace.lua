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
	if node.srt == nil then
		node._worldmat = nil
	else
		node._worldmat = math3d.matrix(node.srt)
	end
end

local function update_worldmat(node, parent)
	if parent.changed > node.changed then
		node.changed = parent.changed
	end
	if parent._worldmat then
		if node.srt == nil then
			node._worldmat = math3d.matrix(parent._worldmat)
		else
			node._worldmat = math3d.mul(parent._worldmat, math3d.matrix(node.srt))
		end
	else
		if node.srt == nil then
			node._worldmat = nil
		else
			node._worldmat = math3d.matrix(node.srt)
		end
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
    return reference[1] ~= nil
end

function s:entity_init()
	local needsync = false

	for v in w:select "INIT camera:in scene:out" do
		local camera = v.camera
		v.scene = {
			srt = mu.srt_obj{s=1, r=math3d.torotation(math3d.vector(camera.viewdir)), t=camera.eyepos},
			updir = math3d.ref(math3d.vector(camera.updir)),
		}
	end
	for v in w:select "INIT mesh:in scene:in" do
		local mesh = v.mesh
		if mesh.bounding then
			v.scene.aabb = mesh.bounding.aabb
		end
	end
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
	for v in w:select "INIT camera:in scene:in" do
		v.camera.srt = v.scene.srt
	end
	for v in w:select "INIT render_object:in scene:in" do
		v.render_object.srt = v.scene.srt
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
			if not parent or not isValidReference(parent) then
				e.scene.parent = nil
			else
				w:sync("scene:in", parent)
				e.scene.parent = parent.scene.id
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
	for v in w:select "scene:in follow_joint:in follow_flag:in" do
        if v.follow_joint ~= "None" then
            for e in w:select "skeleton:in pose_result:in" do
                if e.scene.id == v.scene.parent then
                    local ske = e.skeleton._handle
                    local joint_idx = ske:joint_index(v.follow_joint)
                    local adjust_mat = e.pose_result:joint(joint_idx)
                    local scale, rotate, pos = math3d.srt(adjust_mat)
                    if v.follow_flag == 1 then
                        scale, rotate, pos = 1, {0,0,0,1}, pos
                    elseif v.follow_flag == 2 then
						scale, rotate, pos = 1, rotate, pos
                    end
					local srt = v.scene.srt
					srt.s.v = scale
					srt.r.q = rotate
					srt.t.v = pos
                    --v.scene.srt = math3d.ref(math3d.mul(adjust_mat, v.scene.srt))
                end
            end
        end
    end

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
	for v in w:select "camera:in scene:in" do
		local r, n = v.camera, v.scene
		r.worldmat = n._worldmat
		r.updir = n.updir
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
