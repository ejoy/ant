local ecs = ...
local world = ecs.world

local math3d = require "math3d"

local filter_system = ecs.system "filter_system"

local iss = world:interface "ant.scene|iscenespace"
local ies = world:interface "ant.scene|ientity_state"
local itransform = world:interface "ant.scene|itransform"

local function update_lock_target_transform(eid, lt, im, tr)
	local e = world[eid]
	local trans = e.transform
	if trans == nil then
		error("lock target need, but transform not provide")
	end

	local locktype = lt.type
	local target = e.parent
	
	if locktype == "move" then
		local worldmat = itransform.worldmat(eid)
		local pos = math3d.index(worldmat, 4)
		if lt.offset then
			pos = math3d.add(pos, lt.offset)
		end
		im.set_position(eid, pos)
		tr.worldmat = math3d.matrix(trans)
	elseif locktype == "rotate" then
		local worldmat = itransform.worldmat(eid)

		local pos = im.get_position(eid)
		local targetpos = math3d.index(worldmat, 4)
		im.set_direction(eid, math3d.normalize(math3d.sub(targetpos, pos)))
		if lt.offset then
			im.set_position(eid, math3d.add(pos, lt.offset))
		end
		tr.worldmat = math3d.matrix(trans)
	elseif locktype == "ignore_scale" then
		if trans == nil then
			error(string.format("'ignore_scale' could not bind to entity without 'transform' component"))
		end

		local te = world[target]
		local target_trans = te.transform

		local _, r, t = math3d.srt(target_trans)
		local m = math3d.matrix{s=1, r=r, t=t}
		tr.worldmat = math3d.mul(m, trans)
	else
		error(("not support locktype:%s"):format(locktype))
	end
end

local function update_bounding(rc, e)
	local mesh = e.mesh
	if mesh then
		local bounding = mesh.bounding
		if bounding then
			rc.aabb = math3d.aabb_transform(rc.worldmat, bounding.aabb)
			return
		end
	end

	rc.aabb = nil
end

local function update_transform(eid)
	local e = world[eid]
	local rc = e._rendercache
	if rc.srt == nil and e.parent == nil then
		return
	end

	rc.worldmat = rc.srt and math3d.matrix(rc.srt) or nil

	if e.parent then
		local im = e.camera and 
					world:interface "ant.objcontroller|camera_motion" or
					world:interface "ant.objcontroller|obj_motion"
		local lt = e.lock_target
		if lt then
			update_lock_target_transform(eid, lt, im, rc)
		else	-- combine parent transform
			local pe = world[e.parent]
			-- need apply before tr.worldmat
			local bs_idx = e._bind_slot_idx
			if bs_idx then
				local t = pe.pose_result:joint(bs_idx)
				rc.worldmat = math3d.mul(t, rc.worldmat)
			end
			local p_rc = pe._rendercache
			if p_rc.worldmat then
				rc.worldmat = rc.worldmat and math3d.mul(p_rc.worldmat, rc.worldmat) or math3d.matrix(p_rc.worldmat)
			end
		end
	end

	if rc.worldmat then
		update_bounding(rc, e)
	end
end

local function update_state(eid)
	--TODO: need update by event
	local e = world[eid]
	e._rendercache.entity_state = e.state
end

local filters = {}
function filter_system:post_init()
	for _, eid in world:each "primitive_filter" do
		local e = world[eid]
		local pf = e.primitive_filter
		filters[pf.filter_type] = eid
	end
end

local function can_render(rc)
	return rc.entity_state ~= 0 and rc.vb and rc.fx and rc.state and rc.worldmat
end

local function add_filter_list(eid, filters)
	local rc = world[eid]._rendercache
	if rc == nil then
		return
	end
	local needset = can_render(rc)

	local entity_state = rc.entity_state
	local stattypes = ies.get_state_type()
	for n, filtereid in pairs(filters) do
		local fe = world[filtereid]
		if fe.visible then
			local mask = assert(stattypes[n])
			local filter = fe.primitive_filter
			if needset and ((entity_state & mask) ~= 0) then
				local resulttarget = filter.result[rc.fx.setting.transparency]
				resulttarget.items[eid] = rc
			else
				filter.result.opaticy.items[eid] = nil
				filter.result.translucent.items[eid] = nil
			end
		end
	end
end

local function update_renderinfo(eid)
	update_transform(eid)
	update_state(eid)
end

function filter_system:filter_render_items()
	for _, eid in ipairs(iss.scenequeue()) do
		update_renderinfo(eid)
		add_filter_list(eid, filters)
	end
end