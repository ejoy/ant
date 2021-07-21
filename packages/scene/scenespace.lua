local ecs = ...
local world = ecs.world

local math3d = require "math3d"

----iscenespace----
local m = ecs.action "mount"
function m.init(prefab, i, value)
	local e = world[prefab[i]]
    e.parent = prefab[value]
end

local iss = ecs.interface "iscenespace"
function iss.set_parent(eid, peid)
	world[eid].parent = peid
	world:pub {"component_changed", "parent", eid}
end

----scenespace_system----
local sp_sys = ecs.system "scenespace_system"

local se_mb = world:sub {"component_register", "scene_entity"}
local pc_mb = world:sub {"component_changed", "parent"}

local hie_scene = require "hierarchy.scene"
local scenequeue = hie_scene.queue()

local function inherit_entity_state(e)
	local s = e.state or 0
	local pe = world[e.parent]
	local ps = pe.state
	if ps then
		local MASK <const> = (1 << 32) - 1
		e.state = ((s>>32) | s | ps) & MASK
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

function sp_sys:update_hierarchy()
	for _, _, eid in se_mb:unpack() do
		local e = world[eid]
		scenequeue:mount(eid, e.parent or 0)
		if e.parent then
			inherit_entity_state(e)
			inherit_material(e)
		end
	end

	for _, _, eid in pc_mb:unpack() do
		local e = world[eid]
		scenequeue:mount(eid, e.parent or 0)
	end
end


local function update_bounding(rc, e)
	local worldmat = rc.worldmat
	local bounding = e._bounding
	if worldmat == nil or bounding == nil then
		rc.aabb = nil
	else
		rc.aabb = math3d.aabb_transform(rc.worldmat, bounding.aabb)
	end
end

local function update_transform(eid)
	local e = world[eid]
	local rc = e._rendercache
	if rc.srt == nil and e.parent == nil then
		return
	end

	rc.worldmat = rc.srt and math3d.matrix(rc.srt) or nil

	if e.parent then
		-- combine parent transform
		if e.lock_target == nil then
			local pe = world[e.parent]
			local p_rc = pe._rendercache
			if p_rc.worldmat then
				rc.worldmat = rc.worldmat and math3d.mul(p_rc.worldmat, rc.worldmat) or math3d.matrix(p_rc.worldmat)
			end
		end
	end

	update_bounding(rc, e)
end

function sp_sys:update_transform()
	for _, eid in ipairs(scenequeue) do
		update_transform(eid)
	end
end

function sp_sys:end_frame()
	local need_remove_eids = {}
	for _, eid in world:each "removed" do
		need_remove_eids[eid] = true
	end

	if next(need_remove_eids) then
		local function is_parent_removed(eid)
			return need_remove_eids[eid]
		end

		for _, eid in ipairs(scenequeue) do
			if need_remove_eids[eid] then
				scenequeue:mount(eid)
			elseif is_parent_removed(world[eid].parent) then
				scenequeue:mount(eid, 0)
				iss.set_parent(eid, nil)
			end
		end
		scenequeue:clear()
	end
end

local hiemodule 		= require "hierarchy"
local math3d_adapter 	= require "math3d.adapter"

local mathadapter_util = import_package "ant.math.adapter"

mathadapter_util.bind("hierarchy", function ()
	local node_mt 			= hiemodule.node_metatable()
	node_mt.add_child 		= math3d_adapter.format(node_mt.add_child, "vqv", 3)
	node_mt.set_transform 	= math3d_adapter.format(node_mt.set_transform, "vqv", 2)
	node_mt.transform 		= math3d_adapter.getter(node_mt.transform, "vqv", 2)

	local builddata_mt = hiemodule.builddata_metatable()
	builddata_mt.joint = math3d_adapter.getter(builddata_mt.joint, "m", 2)
end)