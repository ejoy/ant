local ecs = ...
local world = ecs.world

local math3d = require "math3d"

local filter_system = ecs.system "filter_system"

local iss = world:interface "ant.scene|iscenespace"
local ies = world:interface "ant.render|ientity_state"
local iom = world:interface "ant.objcontroller|obj_motion"
local icm = world:interface "ant.objcontroller|camera_motion"

local function update_lock_target_transform(eid, lt, im)
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
		trans._world.m = trans.srt
	elseif locktype == "ignore_scale" then
		if trans == nil then
			error(string.format("'ignore_scale' could not bind to entity without 'transform' component"))
		end

		local te = world[target]
		local target_trans = te.transform.srt

		local _, r, t = math3d.srt(target_trans)
		local m = math3d.matrix{s=1, r=r, t=t}
		trans._world.m = math3d.mul(m, trans.srt)
	else
		error(("not support locktype:%s"):format(locktype))
	end
end

local renderinfo_cache = {
	check_add_cache = function (self, eid)
		local c = self[eid]
		if  c == nil then
			c = {}
			self[eid] = c
		end
		return c
	end,
	cache = function (self, eid, what, value)
		self[eid][what] = value
	end,
	get = function (self, eid, what)
		local c = self[eid]
		if c then
			return c[what]
		end
	end,
}

local function combine_parent_transform(peid, trans)
	local pe = world[peid]
	-- need apply before ptrans._world
	local s = trans._slot_jointidx
	local pr = pe.pose_result
	if s and pr then
		local t = pr:joint(s)
		trans._world.m = math3d.mul(t, trans._world)
	end

	local ptrans = renderinfo_cache:get(peid, "transform")
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
	local e = world[eid]
	local trans = e.transform
	if trans then
		trans._world.m = trans.srt
	end

	if e.parent then
		local im = e.camera and icm or iom
		local lt = im.get_lock_target(eid)
		if lt then
			update_lock_target_transform(eid, lt, im)
		else
			combine_parent_transform(eid, trans)
		end
	end

	if trans then
		update_bounding(trans, e)
		renderinfo_cache:cache(eid, "transform", trans)
	end
end

local function update_rendermesh(eid)
	local mesh = world[eid].mesh
	--TODO: need cache rendermesh
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

		renderinfo_cache:cache(eid, "rendermesh", rendermesh)
	end
end

local function update_material(eid)
	local e = world[eid]
	local m = e.material
	if m == nil then
		local peid = e.parent
		m = renderinfo_cache:get(peid, "material")
		if m == nil then
			return
		end
	end
	renderinfo_cache:cache(eid, "material", m)
end

local function update_state(eid)
	local e = world[eid]
	local s = e.state
	if s then
		local peid = e.parent
		local ps = renderinfo_cache:get(peid, "state")
		if ps then
			local m = s & 0xffffffff00000000
			s = (m | (s & 0xffffffff)|(ps & 0xfffffff))
		end
		renderinfo_cache:cache(eid, "state", s)
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
					ri.aabb 	= t._aabb
					ri.worldmat = t._world
					ri.skinning_matrices = t._skinning_matrices
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
						aabb 	= t._aabb,
						worldmat= t._world,
						skinning_matrices = t._skinning_matrices,
					}
				end
			end
		end
	end
end

local function update_renderinfo(eid)
	local c = renderinfo_cache:check_add_cache(eid)
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