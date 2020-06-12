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
	return (world[eid].state & STATE_TYPE[name]) ~= 0
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

function ies_class.filter_list(eid)
    local state = world[eid].state
	local filters = {}
	--TODO: filter_groups needed!
    for _, eid in world:each "primitive_filter" do
        local pf = world[eid].primitive_filter
        filters[pf.filter_type] = pf
    end

    local l = {}
    for n, mask in pairs(STATE_TYPE) do
		if (state & mask) ~= 0 then
			local f = filters[n]
			if f then
				l[#l+1] = f
			end
        end
    end

    return l
end

function ies_class.create_state(namelist)
	local state = 0
	for name in namelist:gmatch "[%w_]+" do
		state = state | STATE_TYPE[name]
	end

	return state
end