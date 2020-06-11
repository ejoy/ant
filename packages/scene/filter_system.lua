local ecs = ...
local world = ecs.world

local animoudle = require "hierarchy.animation"

local pf = ecs.component "primitive_filter"

function pf:init()
	self.result = {
		translucent = {
			visible_set = {},
			items = {},
		},
		opaticy = {
			visible_set = {},
			items = {},
		},
	}
	return self
end

local prim_filter_sys = ecs.system "primitive_filter_system"

--luacheck: ignore self
local function reset_results(results)
	for k, result in pairs(results) do
		result.n = 0
	end
end

local function add_result(eid, mesh, material, trans, result)
	local idx = result.n + 1
	local r = result[idx]
	if r == nil then
		r = {
			mesh 		= mesh,
			material 	= material,
			transform 	= trans,
			aabb		= trans._aabb,
			eid 		= eid,
		}
		result[idx] = r
	else
		r.mesh 	    = mesh
		r.material 	= material
		r.transform	= trans
		r.aabb		= trans._aabb
		r.eid 		= eid
	end
	result.n = idx
	return r
end

function prim_filter_sys:filter_primitive()
	-- for _, prim_eid in world:each "primitive_filter" do
	-- 	local e = world[prim_eid]
	-- 	local filter = e.primitive_filter
	-- 	reset_results(filter.result)
	-- 	local filtertag = filter.filter_type

	-- 	for _, eid in world:each(filtertag) do
	-- 		local ce = world[eid]
	-- 		if ce[filtertag] then
	-- 			local material = ce.material
	-- 			local resulttarget = assert(filter.result[material.fx.surface_type.transparency])
	-- 			add_result(eid, ce.rendermesh, material, ce.transform, resulttarget)
	-- 		end
	-- 	end
	-- end
end

-- local filter_primitive_mb = world:sub{"filter_primitive"}

-- local register_pf_mb = world:sub{"component_register", "primitive_filter"}

-- local filter_group_mask = {
-- 	visible 	= 0x00000001,
-- 	cast_shadow = 0x00000002,
-- 	selectable 	= 0x00000004,
-- }

-- local filters = {}
-- function prim_filter_sys:data_changed()
-- 	for _, _, eid in ipairs (register_pf_mb) do
-- 		local e = world[eid]
-- 		local pf = e.primitive_filter
-- 		local mask = filter_group_mask[pf.filter_tag]
-- 		filters[mask] = pf
-- 	end
-- end

-- local function update_render_item(eid)
-- 	local e = world[eid]

-- 	local gs = e.group_state

-- 	for i=0, 31 do
-- 		local t = gs & (1 << i)
-- 		if t ~= 0 then
-- 			local filter = filters[t]
-- 			local ri = {}
-- 			local function fetch_meshinfo(e, ri)
-- 				local mesh = e.mesh
				
-- 			end

-- 			local function fetch_materialinfo(e, ri)
-- 			end

-- 			local function fetch_transform(e, ri)
-- 			end

-- 			fetch_meshinfo(e, ri)
-- 			fetch_materialinfo(e, ri)
-- 			fetch_transform(e, ri)

-- 			filter[eid] = ri
-- 		end
-- 	end
-- end

-- function prim_filter_sys:filter_primitive2()
-- 	for _, eid in filter_primitive_mb:unpack() do
-- 		update_render_item(eid)
-- 	end
-- end