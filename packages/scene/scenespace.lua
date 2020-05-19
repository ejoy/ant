local ecs = ...
local world = ecs.world
local math3d = require "math3d"

local m = ecs.connection "mount"
function m.init(e, v)
    e.parent = v
end
function m.save(e)
    return e.parent
end


local t = ecs.component "transform"

function t:init()
    self._world = math3d.ref(self.srt)
    return self
end

local tt = ecs.transform "transform_transform"

function tt.process(e)
	local lt = e.transform.lock_target
	if lt and e.parent == nil then
		error(string.format("'lock_target' defined in 'transform' component, but 'parent' component not define in entity"))
	end
end

local sp_sys = ecs.system "scenespace_system"

local iom = world:interface "ant.objcontroller|obj_motion"
local icm = world:interface "ant.objcontroller|camera_motion"

local se_mb = world:sub {"component_register", "scene_entity"}
local eremove_mb = world:sub {"entity_removed"}

local hie_scene = require "hierarchy.scene"
local scenequeue = hie_scene.queue()

function sp_sys:update_hierarchy_scene()
	for _, _, eid in se_mb:unpack() do
		local e = world[eid]
        scenequeue:mount(eid, e.parent or 0)
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

local function update_lock_target_transform(eid, lt, target, im)
	local locktype = lt.type
	local e = world[eid]
	if locktype == "move" then
		local te = world[target]
		local target_trans = te.transform
		local pos = math3d.index(target_trans.world, 4)
		if lt.offset then
			pos = math3d.add(pos, lt.offset)
		end
		im.set_position(eid, pos)
		local trans = e.transform
		trans._world.m = trans.srt
	elseif locktype == "rotate" then
		local te = world[target]
		local transform = te.transform

		local pos = im.get_position(eid)
		local targetpos = math3d.index(transform.world, 4)
		im.set_direction(eid, math3d.normalize(math3d.sub(targetpos, pos)))
		if lt.offset then
			im.set_position(eid, math3d.add(pos, lt.offset))
		end
		local trans = e.transform
		trans._world.m = trans.srt
	elseif locktype == "ignore_scale" then
		local trans = e.transform
		if trans == nil then
			error(string.format("'ignore_scale' could not bind to entity without 'transform' component"))
		end

		local te = world[target]
		local target_trans = te.transform.srt

		local _, r, t = math3d.srt(target_trans)
		local m = math3d.matrix{s=1, r=r, t=t}
		trans._world.m = math3d.mul(m, trans.srt)
	else
		error(string.format("not support locktype:%s", locktype))
	end
end

local function combine_parent_transform(e, trans)
	local peid = e.parent
	if peid then
		local pe = world[peid]
		local ptrans = pe.transform
		
		if ptrans then
			local pw = ptrans._world
			trans._world.m = math3d.mul(pw, trans._world)
		end
	end
end

local function update_bounding(trans, e)
	local bounding = e.rendermesh.bounding
	if bounding then
		trans._aabb = math3d.aabb_transform(trans._world, bounding.aabb)
	end
end

local function update_transform(eid)
	--update local info
	local e = world[eid]
	local trans = e.transform
	if trans then
		trans._world.m = trans.srt

		--combine parent info
		local im = e.camera and icm or iom
		local lt = im.get_lock_target(eid)

		if lt then
			update_lock_target_transform(eid, lt, e.parent, im)
		else
			combine_parent_transform(e, trans)
		end

		update_bounding(trans, e)
	end
end

function sp_sys:update_transform()
	for _, eid in ipairs(scenequeue) do
		-- hierarchy scene can do everything relative to hierarchy, such as:
		-- hierarhcy visible/material/transform, and another reasonable data
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