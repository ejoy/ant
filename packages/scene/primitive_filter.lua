local ecs = ...
local world = ecs.world

local ipf = ecs.interface "iprimitive_filter"
function ipf.select_filters(eid)
	local e = world[eid]
	local rc = e._rendercache
	local state = rc.entity_state
	if state == nil then
		return
	end

	local needadd = rc.vb and rc.fx and rc.state
	for _, feid in world:each "primitive_filter" do
		local filter = world[feid].primitive_filter
		local fx = rc.fx
		if fx then
			local item
			if needadd and ((state & filter.filter_mask) ~= 0) and ((state & filter.exclude_mask) == 0) then
				item = rc
			end

			filter:insert_item(fx.setting.surfacetype, eid, item)
		end
	end
end

function ipf.reset_filters(eid)
	for _, feid in world:each "primitive_filter" do
		local filter = world[feid].primitive_filter

		for n, f in pairs(filter.result) do
			ipf.remove_item(f.items, eid)
		end
	end
end

function ipf.filter_order(eid)
	return world[eid].filter_order
end

function ipf.find_item(items, eid)
	for i=1, #items do
		if items[i].eid == eid then
			return i
		end
	end
end

function ipf.remove_item(items, eid)
	local idx = ipf.find_item(items, eid)
	if idx then
		table.remove(items, idx)
	end
end

function ipf.add_item(items, eid, item)
	local idx = ipf.find_item(items, eid) or (#items+1)
	items[idx] = assert(item)
end

function ipf.set_sort(eid, surfacetype, sortfunc)
	world[eid].primitive_filter.result[surfacetype].sort = sortfunc
end

function ipf.iter_target(result)
	local vs = result.visible_set or result.items
	local n = vs.n or #vs
	return function (t, idx)
		if idx < n then
			idx = idx + 1
			return idx, t[idx]
		end
	end, vs, 0
end

function ipf.iter_filter(filter)
	local results = filter.result
	local orders = filter.filter_order
	local n = #orders
	return function (t, idx)
		if idx < n then
			idx = idx + 1
			local fn = t[idx]
			local r = results[fn]
			if r.sort then
				r:sort()
			end
			return idx, r
		end
	end, orders, 0
end

local ies = world:interface "ant.scene|ientity_state"

local pf = ecs.component "primitive_filter"

local default_filter_order = {
	"foreground", "opaticy", "background", "translucent", "decal", "ui"
}

local function default_filter(needcull, sort)
	return {
		items = {},
		visible_set = needcull and {n=0} or nil,
		sort = sort,
	}
end

function pf:init()
	self.result = {
		translucent	= default_filter(true),
		opaticy		= default_filter(true),
        decal		= default_filter(true),
		foreground	= default_filter(),
		background	= default_filter(),
		ui			= default_filter(nil,
					function (result)
						local vs = result.visible_set or result.items
						local n = vs.n or #vs
						vs[n+1] = nil
						table.sort(vs, function (lhs, rhs)
							return lhs.depth > rhs.depth
						end)
					end)
	}
	self.filter_mask = ies.filter_mask(self.filter_type)
	self.exclude_mask = self.exclude_type and ies.filter_mask(self.exclude_type) or 0
	self.filter_order = self.filter_order or default_filter_order
	return self
end


local vpt = ecs.transform "primitive_filter_transform"
-- local function parse_rc(rc)
-- 	local state = bgfx.parse_state(rc.state)
-- 	local wm = state.WRITE_MASK:gsub("Z", "")
-- 	if wm ~= state.WRITE_MASK then
-- 		state.DEPTH_TEST = "EQUAL"
-- 		state.WRITE_MASK = wm
-- 		return setmetatable({
-- 			state = bgfx.make_state(state)
-- 		}, {__index=rc})
-- 	end
-- 	return rc
-- end

function vpt.process_entity(e)
	local f = e.primitive_filter
	f.insert_item = function (filter, fxtype, eid, rc)
		local items = filter.result[fxtype].items
		if rc then
			rc.eid = eid
			ipf.add_item(items, eid, rc) --parse_rc(rc))
		else
			ipf.remove_item(items, eid)
		end
	end
end
