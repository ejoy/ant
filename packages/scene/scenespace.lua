local ecs = ...
local world = ecs.world

local math3d = require "math3d"

local ipf = world:interface "ant.scene|iprimitive_filter"

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
local eremove_mb = world:sub {"entity_removed"}

local hie_scene = require "hierarchy.scene"
local scenequeue = hie_scene.queue()

local function bind_joint_entity(e)
	local joint = e.follow_joint
	if joint then
		local pe = world[e.parent]
		local pr = pe.pose_result
		if pr and pe.skeleton then
			local ske = assert(pe.skeleton)._handle
			e._follow_joint_idx = ske:joint_index(joint)
		end
	end
end

local function inherit_entity_state(e)
	local s = e.state or 0
	local pe = world[e.parent]
	local ps = pe.state
	if ps then
		local m = s & 0xffffffff00000000
		e.state = (m | (s & 0xffffffff)|(ps & 0xfffffff))
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
		if e then
			scenequeue:mount(eid, e.parent or 0)
			if e.parent then
				bind_joint_entity(e)
				inherit_entity_state(e)
				inherit_material(e)
			end
			ipf.select_filters(eid)
		end
	end
	
	for _, _, eid in pc_mb:unpack() do
		local e = world[eid]
		scenequeue:mount(eid, e.parent or 0)
	end

    local needclear
    for _, eid in eremove_mb:unpack() do
		--TODO: fix remove branch
		local function mount_children()
			local children = {}
			for _, ceid in world:each "scene_entity" do
				local ce = world[ceid]
				if ce.parent == eid then
					scenequeue:mount(ceid, 0)
					ce.parent = nil
				end
			end
			return children
		end
		mount_children()
		scenequeue:mount(eid)
		ipf.reset_filters(eid)
        needclear = true
    end

    if needclear then
        scenequeue:clear()
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
			-- need apply before tr.worldmat
			local joint_idx = e._follow_joint_idx
			if joint_idx then
				local adjust_mat = pe.pose_result:joint(joint_idx)
				local scale, rotate, pos = math3d.srt(adjust_mat)
				if e.follow_flag == 1 then
					adjust_mat = math3d.matrix {s=1, r={0,0,0,1}, t=pos}
				elseif e.follow_flag == 2 then
					adjust_mat = math3d.matrix {s=1, r=rotate, t=pos}
				end
				rc.worldmat = math3d.mul(adjust_mat, rc.worldmat)
			end
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