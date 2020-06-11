local ecs = ...
local world = ecs.world

local math3d = require "math3d"

local filter_system = ecs.system "filter_system"

local iss = world:interface "ant.scene|iscenespace"
local ies = world:interface "ant.scene|ientity_state"
local iom = world:interface "ant.objcontroller|obj_motion"
local icm = world:interface "ant.objcontroller|camera_motion"

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

local function combine_parent_transform(peid, trans)
	local pe = world[peid]
	-- need apply before ptrans._world
	local s = trans._slot_jointidx
	local pr = pe.pose_result
	if s and pr then
		local t = pr:joint(s)
		trans._world.m = math3d.mul(t, trans._world)
	end

	local ptrans = ies.component(peid, "transform")
	if ptrans then
		local pw = ptrans._world
		trans._world.m = math3d.mul(pw, trans._world)
	end
end

local function update_bounding(trans, e)
	local primgroup = e.rendermesh
	if primgroup then
		local bounding = primgroup.bounding
		if bounding then
			trans._aabb = math3d.aabb_transform(trans._world, bounding.aabb)
		end
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
			if e.parent then
				combine_parent_transform(e.parent, trans)
			end
		end

		update_bounding(trans, e)
	end
	return trans
end

local function update_rendermesh(eid)
	local mesh = ies.component(eid, "mesh")
	if mesh then
		local handles = {}
		local rendermesh = {
			vb = {
				start = mesh.vb.start,
				num = mesh.vb.num,
				handles = handles,
			}
		}
		for _, v in ipairs(mesh.vb) do
			handles[#handles+1] = v.handle
		end
		if mesh.ib then
			rendermesh.ib = {
				start = mesh.ib.start,
				num = mesh.ib.num,
				handle = mesh.ib.handle,
			}
		end

		return rendermesh
	end
end

local function update_material(eid)
	return ies.component(eid, "material")
end

function filter_system:filter_render_items()
	for _, eid in ipairs(iss.scenequeue()) do
		local transform	= update_transform(eid)
		local rendermesh= update_rendermesh(eid)
		local material 	= update_material(eid)

		if transform and rendermesh and material then
			local ri = {
				vb 		= rendermesh.vb,
				ib 		= rendermesh.ib,
				state	= material._state,
				fx 		= material.fx,
				properties = material.properties,
				worldmat= transform._world,
				skinning_matrices = transform._skinning_matrices,
				aabb 	= transform._aabb,
			}
			
			local filterlist = ies.filter_list(eid)
			
			for _, f in ipairs(filterlist) do
				local resulttarget = f.result[material.fx.surface_type.transparency]
				resulttarget.items[eid] = ri
			end
		end
	end
end