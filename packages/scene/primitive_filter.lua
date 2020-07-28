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
		if needadd and ((state & filter.filter_mask) ~= 0) then
			item = rc
		end
		filter:insert_item(rc.fx.setting.transparency, eid, item)
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

local ies = world:interface "ant.scene|ientity_state"

local pf = ecs.component "primitive_filter"
function pf:init()
	self.result = {
		translucent = {
			items = {},
		},
		opaticy = {
			items = {},
		},
	}
	self.filter_mask = ies.filter_mask(self.filter_type)
	return self
end