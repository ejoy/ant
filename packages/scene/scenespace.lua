local ecs = ...
local world = ecs.world
local math3d = require "math3d"

local sp_sys = ecs.system "scenespace_system"
sp_sys.require_interface "ant.objcontroller|obj_motion"
sp_sys.require_interface "ant.objcontroller|camera_motion"

local iom = world:interface "ant.objcontroller|obj_motion"
local icm = world:interface "ant.objcontroller|camera_motion"

local se_mb = world:sub {"component_register", "scene_entity"}
local eremove_mb = world:sub {"entity_removed"}

local hie_scene = require "hierarchy.scene"
local scenequeue = hie_scene.queue()

local function find_mount_target(e)
	local p = e.parent
	if p then
		return p
	end

	local lt = e.lock_target
	if lt then
		return lt.target
	end

	return 0
end

function sp_sys:update_hierarchy_scene()
	for _, _, eid in se_mb:unpack() do
		local e = world[eid]
		
		local mounttarget = find_mount_target(e)
        scenequeue:mount(eid, mounttarget)
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

local function update_lock_target(e, lt)
	local im = e.camera and icm or iom
	local locktype = lt.type
	if locktype == "move" then
		local te = world[lt.target]
		local target_trans = te.transform
		local pos = math3d.index(target_trans.world, 4)
		if lt.offset then
			pos = math3d.add(pos, lt.offset)
		end
		im.set_position(e, pos)
		local trans = e.transform
		trans.world.m = trans.srt
	elseif locktype == "rotate" then
		local te = world[lt.target]
		local transform = te.transform

		local pos = im.get_position(e)
		local targetpos = math3d.index(transform.world, 4)
		im.set_direction(e, math3d.normalize(math3d.sub(targetpos, pos)))
		if lt.offset then
			im.set_position(e, math3d.add(pos, lt.offset))
		end
		local trans = e.transform
		trans.world.m = trans.srt
	elseif locktype == "ignore_scale" then
		local trans = e.transform
		if trans == nil then
			error(string.format("'ignore_scale' could not bind to entity without 'transform' component"))
		end

		local te = world[lt.target]
		local target_trans = te.transform.srt

		local _, r, t = math3d.srt(target_trans)
		local m = math3d.matrix{s=1, r=r, t=t}
		trans.world.m = math3d.mul(m, trans.srt)
	else
		error(string.format("not support locktype:%s", locktype))
	end
end

local function update_transform(e)
	--update local info
	local trans = e.transform
	if trans then
		trans.world.m = trans.srt
	end

	--combine parent info
	local lt = e.lock_target
	if lt then
		update_lock_target(e)
	else
		local peid = e.parent
		if peid then
			local pe = world[peid]
			local ptrans = pe.transform
			
			if ptrans then
				local pw = ptrans.world
				trans.world.m = math3d.mul(pw, trans.world)
			end
		end
	end
end

function sp_sys:update_transform()
	for _, eid in ipairs(scenequeue) do
		local e = world[eid]

		-- hierarchy scene can do everything relative to hierarchy, such as:
		-- hierarhcy visible/material/transform, and another reasonable data
		update_transform(e)
	end
end