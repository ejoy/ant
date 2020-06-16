local ecs = ...
local world = ecs.world
local math3d = require "math3d"

local m = ecs.action "mount"
function m.init(e, prefab, value)
    e.parent = prefab[value]
end
function m.save(e, prefab)
	for i, v in ipairs(prefab) do
		if v == e.parent then
			return i
		end
	end
end

local pf = ecs.component "primitive_filter"

function pf:init()
	self.result = {
		translucent = {
			items = {},
		},
		opaticy = {
			items = {},
		},
	}
	return self
end

local sp_sys = ecs.system "scenespace_system"

local se_mb = world:sub {"component_register", "scene_entity"}
local eremove_mb = world:sub {"entity_removed"}

local hie_scene = require "hierarchy.scene"
local scenequeue = hie_scene.queue()

local iss = ecs.interface "iscenespace"
function iss.scenequeue()
	return scenequeue
end

local function bind_slot_entity(e)
	local trans = e.transform
	if trans and trans.slot then
		local pe = world[e.parent]
		local pr = pe.pose_result
		if pr and pe.skeleton then
			local ske = assert(pe.skeleton)._handle
			trans._slot_jointidx = ske:joint_index(trans.slot)
		end
	end
end

function sp_sys:update_hierarchy_scene()
	for _, _, eid in se_mb:unpack() do
		local e = world[eid]
		scenequeue:mount(eid, e.parent or 0)

		if e.parent then
			bind_slot_entity(e)
		end
    end

    local needclear
    for _, eid in eremove_mb:unpack() do
        scenequeue:mount(eid)
        needclear = true
    end

    if needclear then
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