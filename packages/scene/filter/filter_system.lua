local ecs = ...
local world = ecs.world

local math3d = require "math3d"

local filter_system = ecs.system "filter_system"

local iss = world:interface "ant.scene|iscenespace"
local ies = world:interface "ant.scene|ientity_state"


local function update_lock_target_transform(eid, lt, im, tr)
	local e = world[eid]
	local trans = e.transform
	if trans == nil then
		error("lock target need, but transform not provide")
	end

	local locktype = lt.type
	local target = e.parent
	
	if locktype == "move" then
		local te = world[target]
		local target_trans = te.transform
		local pos = math3d.index(target_trans.world, 4)
		if lt.offset then
			pos = math3d.add(pos, lt.offset)
		end
		im.set_position(eid, pos)
		tr.worldmat = math3d.matrix(trans.srt)
	elseif locktype == "rotate" then
		local te = world[target]
		local transform = te.transform

		local pos = im.get_position(eid)
		local targetpos = math3d.index(transform.world, 4)
		im.set_direction(eid, math3d.normalize(math3d.sub(targetpos, pos)))
		if lt.offset then
			im.set_position(eid, math3d.add(pos, lt.offset))
		end
		tr.worldmat = math3d.matrix(trans.srt)
	elseif locktype == "ignore_scale" then
		if trans == nil then
			error(string.format("'ignore_scale' could not bind to entity without 'transform' component"))
		end

		local te = world[target]
		local target_trans = te.transform.srt

		local _, r, t = math3d.srt(target_trans)
		local m = math3d.matrix{s=1, r=r, t=t}
		tr.worldmat = math3d.mul(m, trans.srt)
	else
		error(("not support locktype:%s"):format(locktype))
	end
end

local function combine_parent_transform(peid, trans, rc)
	local pe = world[peid]
	-- need apply before tr.worldmat
	if trans then
		local s = trans._slot_jointidx
		local pr = pe.pose_result
		if s and pr then
			local t = pr:joint(s)
			rc.worldmat = math3d.mul(t, rc.worldmat)
		end
	end

	if rc then
		local p_rc = pe._rendercache
		if p_rc and p_rc.worldmat then
			rc.worldmat = rc.worldmat and math3d.mul(p_rc.worldmat, rc.worldmat) or math3d.matrix(p_rc.worldmat)
		end
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
	local etrans = e.transform

	if etrans == nil and e.parent == nil then
		return
	end

	--entity with no transform but parent have, we need to cache a matrix that copy from parent
	if etrans == nil and e.parent and e._rendercache == nil then
		e._rendercache = {}
	end
	local rc = e._rendercache
	rc.worldmat = etrans and math3d.matrix(etrans.srt) or nil

	if e.parent then
		local im = e.camera and 
					world:interface "ant.objcontroller|camera_motion" or
					world:interface "ant.objcontroller|obj_motion"
		local lt = etrans and im.get_lock_target(eid) or nil
		if lt then
			update_lock_target_transform(eid, lt, im, rc)
		else
			combine_parent_transform(e.parent, etrans, rc)
		end
	end

	rc.skinning_matrices = e.skinning and e.skinning.skinning_matrices or nil

	if rc.worldmat then
		update_bounding(rc, e)
	end
end

local function update_material(eid)
	--TODO: need move to 'mount' action
	local e = world[eid]
	if e.parent then
		local pe = world[e.parent]
		local p_rc = pe._rendercache
		if p_rc then
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
	end
end

local function update_state(eid)
	local e = world[eid]
	local s = e.state
	if s then
		if e.parent then
			local pe = world[e.parent]
			local ps = pe.state
			if ps then
				local m = s & 0xffffffff00000000
				s = (m | (s & 0xffffffff)|(ps & 0xfffffff))
			end
		end

		e._rendercache.entity_state = s
	end
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
	return rc and rc.entity_state ~= 0 and rc.vb and rc.fx and rc.state and rc.worldmat
end

local function add_filter_list(eid, filters)
	local rc = world[eid]._rendercache
	if not can_render(rc) then
		return
	end

	local entity_state = rc.entity_state
	local stattypes = ies.get_state_type()
	for n, filtereid in pairs(filters) do
		local fe = world[filtereid]
		if fe.visible then
			local mask = assert(stattypes[n])
			if (entity_state & mask) ~= 0 then
				local filter = fe.primitive_filter
				
				local resulttarget = filter.result[rc.fx.setting.transparency]
				resulttarget.items[eid] = rc
			end
		end
	end
end

local function update_renderinfo(eid)
	update_transform(eid)
	update_material(eid)
	update_state(eid)
end

function filter_system:filter_render_items()
	for _, eid in ipairs(iss.scenequeue()) do
		update_renderinfo(eid)
		add_filter_list(eid, filters)
	end
end

local it = ecs.interface "itransform"
function it.worldmat(eid)
	local rc = world[eid]._rendercache
	if rc then
		return rc.worldmat
	end
end