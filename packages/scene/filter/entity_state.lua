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

local ies_class = ecs.interface "ientity_state"
local ies = world:interface "ant.scene|ientity_state"

function ies_class.has_state(eid, name)
	local s = world[eid].state
	if s then
		return (s& STATE_TYPE[name]) ~= 0
	end
end

function ies_class.set_state(eid, name, v)
	if not ies.has_state(eid, name) then
		return
	end
	local state = world[eid].state
	if v then
		world[eid].state = state | STATE_TYPE[name]
	else
		world[eid].state = state & (~STATE_TYPE[name])
	end
	print("after set_state", world[eid].state)
end

function ies_class.can_visible(eid)
	return ies.has_state(eid, "visible")
end

function ies_class.can_cast(eid)
	return ies.has_state(eid, "cast_shadow")
end

function ies_class.can_select(eid)
	return ies.has_state(eid, "selectable")
end

function ies_class.get_state_type()
	return STATE_TYPE
end

function ies_class.create_state(namelist)
	local state = 0
	for name in namelist:gmatch "[%w_]+" do
		state = state | STATE_TYPE[name]
	end

	return state
end