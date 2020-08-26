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

local ies = world:interface "ant.scene|ientity_state"

local pf = ecs.component "primitive_filter"

local default_filter_order = {
	"foreground", "opaticy", "background", "translucent", "decal", "ui"
}

function pf:init()
	self.result = {
		translucent = {
			items = {},
			needcull = true,
		},
		opaticy = {
			items = {},
			needcull = true,
        },
        decal = {
			items = {},
			needcull = true,
		},
		foreground = {
			items = {},
		},
		background = {
			items = {},
		},
		ui = {
			items = {},
		}
	}
	self.filter_mask = ies.filter_mask(self.filter_type)
	self.filter_order = self.filter_order or default_filter_order
	return self
end