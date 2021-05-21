local ecs = ...
local world = ecs.world

local STATE_TYPE = {
	---
	visible 	= 0x00000001,
	cast_shadow	= 0x00000002,
	selectable	= 0x00000004,

	--
	blit_view	= 0x00000008,
	lightmap	= 0x00000010,
	--
	auxgeom		= 0x00010000,
}

local es_trans = ecs.transform "entity_state_transform"

function es_trans.process_entity(e)
	local rc = e._rendercache
	rc.entity_state = e.state or 0
end

local ies = ecs.interface "ientity_state"

local ipf = world:interface "ant.scene|iprimitive_filter"

function ies.has_state(eid, name)
	return ((world[eid]._rendercache.entity_state) & STATE_TYPE[name]) ~= 0
end

function ies.set_state(eid, name, v)
	local rc = world[eid]._rendercache
	if not rc or not rc.entity_state then
		return
	end
	if v then
		rc.entity_state = rc.entity_state | STATE_TYPE[name]
	else
		rc.entity_state = rc.entity_state & (~STATE_TYPE[name])
	end
	ipf.select_filters(eid)
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

function ies.filter_mask(t)
	return STATE_TYPE[t]
end