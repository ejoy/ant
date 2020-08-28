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
		local item
		if needadd and ((state & filter.filter_mask) ~= 0) and ((state & filter.exclude_mask) == 0) then
			item = rc
		end
		filter:insert_item(rc.fx.setting.surfacetype, eid, item)
	end
end

function ipf.reset_filters(eid)
	for _, feid in world:each "primitive_filter" do
		local filter = world[feid].primitive_filter
		local r = filter.result
		r.opaticy.items[eid] = nil
		r.translucent.items[eid] = nil
	end
end

function ipf.filter_order(eid)
	return world[eid].filter_order
end

function ipf.remove_item(items, eid)
	for i=1, #items do
		local item = items[i]
		if item.eid == eid then
			table.remove(items, i)
			return
		end
	end
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

local ies = world:interface "ant.scene|ientity_state"

local pf = ecs.component "primitive_filter"

local default_filter_order = {
	"foreground", "opaticy", "background", "translucent", "decal", "ui"
}

local function gen_filter(needcull, sort)
	return {
		items = {},
		visible_set = needcull and {n=0} or nil,
		sort = sort,
	}
end

function pf:init()
	self.result = {
		translucent = gen_filter(true),
		opaticy = gen_filter(true),
        decal = gen_filter(true),
		foreground = gen_filter(),
		background = gen_filter(),
		ui = gen_filter(nil,
			function (items)
				table.sort(items, function (lhs, rhs)
					return lhs.depth < rhs.depth
				end)
			end)
	}
	self.filter_mask = ies.filter_mask(self.filter_type)
	self.exclude_mask = self.exclude_type and ies.filter_mask(self.exclude_type) or 0
	self.filter_order = self.filter_order or default_filter_order
	return self
end