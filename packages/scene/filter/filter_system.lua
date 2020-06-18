local ecs = ...
local world = ecs.world

local math3d = require "math3d"

local filter_system = ecs.system "filter_system"

local iss = world:interface "ant.scene|iscenespace"
local ies = world:interface "ant.scene|ientity_state"

local icaches = world:interface "ant.scene|ifilter_cache"

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

local function combine_parent_transform(peid, trans, tr)
	local pe = world[peid]
	-- need apply before tr.worldmat
	if trans then
		local s = trans._slot_jointidx
		local pr = pe.pose_result
		if s and pr then
			local t = pr:joint(s)
			tr.worldmat = math3d.mul(t, tr.worldmat)
		end
	end

	local ptrans = icaches.get(peid, "transform")
	if ptrans then
		tr.worldmat = tr.worldmat and math3d.mul(ptrans.worldmat, tr.worldmat) or math3d.matrix(ptrans.worldmat)
	end
end

local function update_bounding(tr, e)
	local mesh = e.mesh
	if mesh then
		local bounding = mesh.bounding
		if bounding then
			tr.aabb = math3d.aabb_transform(tr.worldmat, bounding.aabb)
		end
	end
end

local function update_transform(eid)
	local tr = {}

	local e = world[eid]
	local etrans = e.transform
	if etrans then
		tr.worldmat = math3d.matrix(etrans.srt)
	end

	if e.parent then
		local im = e.camera and 
					world:interface "ant.objcontroller|camera_motion" or
					world:interface "ant.objcontroller|obj_motion"
		local lt = etrans and im.get_lock_target(eid) or nil
		if lt then
			update_lock_target_transform(eid, lt, im, tr)
		else
			combine_parent_transform(e.parent, etrans, tr)
		end
	end

	if e.skinning then
		tr.skinning_matrices = e.skinning.skinning_matrices
	end

	if tr.worldmat then
		update_bounding(tr, e)
		icaches.cache(eid, "transform", tr)
	end
end

local function update_rendermesh(eid)
	local mesh = world[eid].mesh
	--TODO: need cache
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

		icaches.cache(eid, "rendermesh", rendermesh)
	end
end

local function update_material(eid)
	local m = icaches.get(eid, "material")
	if m == nil then
		local peid = world[eid].parent
		if peid == nil then
			return
		end
		m = icaches.get(peid, "material")
		if m then
			icaches.cache(eid, "material", m)
			return
		end
	end
end

local function update_state(eid)
	local e = world[eid]
	local s = e.state
	if s then
		local peid = e.parent
		local ps = peid and icaches.get(peid, "state") or nil
		if ps then
			local m = s & 0xffffffff00000000
			s = (m | (s & 0xffffffff)|(ps & 0xfffffff))
		end
		icaches.cache(eid, "state", s)
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

local function add_filter_list(eid, filters, renderinfo)
	local w = world

	local rm, m, t = renderinfo.rendermesh, renderinfo.material, renderinfo.transform
	if rm == nil or m == nil or t == nil then
		return
	end
	local state = renderinfo.state
	local stattypes = ies.get_state_type()
	for n, filtereid in pairs(filters) do
		local fe = world[filtereid]
		if fe.visible then
			local mask = assert(stattypes[n])
			if (state & mask) ~= 0 then
				local filter = fe.primitive_filter
				
				local resulttarget = filter.result[m.fx.setting.transparency]
				local ri = resulttarget.items[eid]
				if ri then
					ri.vb 		= rm.vb
					ri.ib 		= rm.ib
					ri.state	= m._state
					ri.fx 		= m.fx
					ri.properties = m.properties
					ri.aabb 	= t.aabb
					ri.worldmat = t.worldmat
					ri.skinning_matrices = t.skinning_matrices
				else
					resulttarget.items[eid] = {
						--
						vb 		= rm.vb,
						ib 		= rm.ib,
						--
						state	= m._state,
						fx 		= m.fx,
						properties = m.properties,
						--
						aabb 	= t.aabb,
						worldmat= t.worldmat,
						skinning_matrices = t.skinning_matrices,
					}
				end
			end
		end
	end
end

local function update_renderinfo(eid)
	local c = icaches.check_add_cache(eid)
	--TODO: need cache all this render information, and watch entity changed, then clean cache
	update_transform(eid)
	update_rendermesh(eid)
	update_material(eid)
	update_state(eid)
	return c
end

function filter_system:filter_render_items()
	for _, eid in ipairs(iss.scenequeue()) do
		add_filter_list(eid, filters, update_renderinfo(eid))
	end
end

local it = ecs.interface "itransform"
function it.worldmat(eid)
	local c = world[eid]._caches
	if c then
		return c.worldmat
	end
end