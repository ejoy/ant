local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"

----iscenespace----
local m = ecs.action "mount"
function m.init(prefab, i, value)
	local e = world[prefab[i]]
    e.parent = prefab[value]
end

local iss = ecs.interface "iscenespace"
function iss.set_parent(eid, peid)
	local e = world[eid]
	e.parent = peid
	if e.scene_entity then
		if peid == nil or world[peid].scene_entity then
			world:pub {"component_changed", "parent", eid}
			return
		end
	end
	assert(false)
end

----scenespace_system----
local s = ecs.system "scenespace_system"

local evChangedParent = world:sub {"component_changed", "parent"}

local hie_scene = require "hierarchy.scene"
local scenequeue = hie_scene.queue()

local function inherit_entity_state(e)
	local state = e.state or 0
	local pe = world[e.parent]
	local pstate = pe.state
	if pstate then
		local MASK <const> = (1 << 32) - 1
		e.state = ((state>>32) | state | pstate) & MASK
	end
end

local function inherit_material(e)
	local pe = world[e.parent]
	local p_rc = pe._rendercache
	local rc = e._rendercache
	if rc.fx == nil then
		rc.fx = p_rc.fx
	end
	if rc.state == nil then
		rc.state = p_rc.state
	end
	if rc.properties == nil then
		rc.properties = p_rc.properties
	end
end

local current_changed = 0

local function mount_scene_node(scene_id)
	local node = w:object("scene_node", scene_id)
	node.changed = current_changed
	if node._parent then
		local parent = world[node._parent]._scene_id
		assert(parent)
		node.parent = parent
		node._parent = nil
		scenequeue:mount(scene_id, parent)
	else
		scenequeue:mount(scene_id, 0)
	end
end

local function update_worldmat(node)
	if not node.parent then
		if node.srt == nil then
			node._worldmat = nil
		else
			node._worldmat = math3d.matrix(node.srt)
		end
		return
	end
	local pnode = w:object("scene_node", node.parent)
	if pnode.changed > node.changed then
		node.changed = pnode.changed
	end
	if pnode._worldmat then
		if node.srt == nil then
			node._worldmat = math3d.matrix(pnode._worldmat)
		else
			node._worldmat = math3d.mul(pnode._worldmat, math3d.matrix(node.srt))
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

local function sync_scene_node()
	w:order("scene_sorted", "scene_node", scenequeue)
end

function s:entity_init()
	local needsync = false
	current_changed = current_changed + 1

	for v in w:select "INIT scene_id:in" do
		mount_scene_node(v.scene_id)
		needsync = true
	end

	for _, _, eid in evChangedParent:unpack() do
		local e = world[eid]
		local id = e._scene_id
		if e.parent then
			local scene_node = w:object("scene_node", id)
			scene_node._parent = e.parent
		end
		mount_scene_node(id)
		needsync = true
	end

	if needsync then
		sync_scene_node()
		for v in w:select "scene_sorted INIT scene_node:in" do
			local node = v.scene_node
			local eid = node._self
			if eid then
				local e = world[eid]
				if e.parent then
					inherit_entity_state(e)
					inherit_material(e)
				end
				node._self = nil
			end
		end
	end
end

function s:update_hierarchy()
end

local evSceneChanged = world:sub {"scene_changed"}

function s:update_transform()
	for _, eid in evSceneChanged:unpack() do
		local node
		if type(eid) == "table" then
			local ref = eid
			w:sync("scene_node(scene_id):in", ref)
			node = ref.node
		else
			local e = world[eid]
			local id = e._scene_id
			node = w:object("scene_node", id)
		end
		node.changed = current_changed
	end
	for v in w:select "scene_sorted scene_node:in" do
		local node = v.scene_node
		update_worldmat(node)
		update_aabb(node)
	end
	for v in w:select "render_object:in scene_node(scene_id):in scene_changed?out" do
		local r, n = v.render_object, v.scene_node
		r.aabb = n._aabb
		r.worldmat = n._worldmat
		if n.changed == current_changed then
			v.scene_changed = true
		end
	end
	for v in w:select "camera_node(camera_id):in scene_node(scene_id):in scene_changed?out" do
		local r, n = v.camera_node, v.scene_node
		r.worldmat = n._worldmat
		if n.changed == current_changed then
			v.scene_changed = true
		end
	end
end

function s:entity_remove()
	w:clear "scene_changed"

	local removed = {}
	for v in w:select "REMOVED scene_id:in" do
		local id = v.scene_id
		removed[id] = true
		w:release("scene_node", id)
	end
	if next(removed) then
		for _, id in ipairs(scenequeue) do
			if removed[id] then
				scenequeue:mount(id)
			else
				local node = w:object("scene_node", id)
				if node.parent and removed[node.parent] then
					--TODO: remove parent in old ecs?
					scenequeue:mount(id, 0)
					node.parent = nil
				end
			end
		end
		scenequeue:clear()
		sync_scene_node()
	end
end
