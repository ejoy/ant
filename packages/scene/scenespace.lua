local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"

----iscenespace----
local iss = ecs.interface "iscenespace"
function iss.set_parent(eid, peid)
	local e = world[eid]
	local pe = world[peid]
	if (not e or e.scene_entity) and (not pe or pe.scene_entity) then
		world:pub {"component_changed", "parent", eid, peid}
	end
end

local m = ecs.action "mount"
function m.init(prefab, i, value)
	iss.set_parent(prefab[i], prefab[value])
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

local function findSceneId(hashmap, eid)
	local id = hashmap[eid]
	if id then
		return id
	end
	local e
	if type(eid) == "table" then
		e = eid
	else
		for v in w:select "eid:in" do
			if v.eid == eid then
				e = v
				break
			end
		end
	end
	w:sync("scene_id:in", e)
	id = e.scene_id
	hashmap[eid] = id
	return id
end

local function findSceneNode(eid)
	for v in w:select "eid:in" do
		if v.eid == eid then
			w:sync("scene_node(scene_id):in", v)
			return v.scene_node
		end
	end
end

function s:entity_init()
	local needsync = false
	current_changed = current_changed + 1

	local hashmap = {}
	for v in w:select "INIT scene:in scene_id:out" do
		local node = v.scene
		v.scene_id = world:luaecs_create_ref {
			scene_node = node,
			initializing = true,
		}
		node.changed = current_changed
		scenequeue:mount(v.scene_id, 0)
		needsync = true
		if node._self then
			hashmap[node._self] = v.scene_id
		end
	end
	w:clear "scene"

	for _, _, eid, peid in evChangedParent:unpack() do
		local scene_id = findSceneId(hashmap, eid)
		local node = w:object("scene_node", scene_id)
		node.changed = current_changed
		if peid then
			node.parent = findSceneId(hashmap, peid)
			scenequeue:mount(scene_id, node.parent)
		else
			scenequeue:mount(scene_id, 0)
		end
		needsync = true
	end

	if needsync then
		sync_scene_node()
		for v in w:select "scene_sorted initializing scene_node:in" do
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
		w:clear "initializing"
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
			node = ref.scene_node
		else
			node = findSceneNode(eid)
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
	for v in w:select "camera:in scene_node(scene_id):in scene_changed?out" do
		local r, n = v.camera, v.scene_node
		r.worldmat = n._worldmat
		r.updir = n.updir
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
