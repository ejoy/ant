local ecs = ...
local world = ecs.world

local STATE_TYPE = {
	---
	visible 	= 0x00000001,
	cast_shadow	= 0x00000002,
	selectable	= 0x00000004,

	--
	blit_view	= 0x00000008,
}

local es_trans = ecs.transform "entity_state_transform"

local function can_render(rc)
	return rc.vb and rc.fx and rc.state
end

local function update_filters(rc, eid)
	local state = rc.entity_state
	if state == nil then
		return
	end
	local needadd = can_render(rc)
	for _, feid in world:each "primitive_filter" do
		local filter = world[feid].primitive_filter
		local m = STATE_TYPE[filter.filter_type]
		if needadd and ((state & m) ~= 0) then
			filter.result[rc.fx.setting.transparency].items[eid] = rc
		end
	end
end

function es_trans.process_entity(e)
	local rc = e._rendercache
	rc.entity_state = e.state or 0
end

local ies = ecs.interface "ientity_state"

function ies.update_filters(eid)
	update_filters(world[eid]._rendercache, eid)
end

function ies.has_state(eid, name)
	return ((world[eid]._rendercache.entity_state) & STATE_TYPE[name]) ~= 0
end

function ies.set_state(eid, name, v)
	local rc = world[eid]._rendercache
	if v then
		rc.entity_state = rc.entity_state | STATE_TYPE[name]
	else
		rc.entity_state = rc.entity_state & (~STATE_TYPE[name])
	end
	update_filters(rc, eid)
	world:pub{"component_changed", "state"}
end

function ies.can_visible(eid)
	return ies.has_state(eid, "visible")
end

function ies.can_cast(eid)
	return ies.has_state(eid, "cast_shadow")
end

function ies.can_select(eid)
	return ies.has_state(eid, "selectable")
end

function ies.get_state_type()
	return STATE_TYPE
end

function ies.create_state(namelist)
	local state = 0
	for name in namelist:gmatch "[%w_]+" do
		state = state | STATE_TYPE[name]
	end

	return state
end