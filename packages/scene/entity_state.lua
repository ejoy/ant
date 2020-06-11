local ecs = ...
local world = ecs.world

local STATE_TYPE = {
	transform 	= 0x00000001,
	material 	= 0x00000002,
	
	---
	visible 	= 0x00010000,
	cast_shadow	= 0x00020000,
	selectable	= 0x00040000,

	--
	blit_view	= 0x80000000,
}

local ies_class = ecs.interface "ientity_state"
local ies = world:interface "ant.scene|ientity_state"

function ies_class.full_state(eid)
	local e = world[eid]
	local state = e.state

	-- merge parent state
	local peid = world.parent
	while peid do
		local pe = world[peid]
		local pstate = pe.state
		local mask = state >> 32
		state = (pstate & (mask~0xffffffff) | (state & mask) | (mask << 32))
		peid = pe.parent
	end

	return state or 0
end

function ies_class.has_state(eid, name)
	return (ies.full_state(eid) & STATE_TYPE[name]) ~= 0
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

function ies_class.component(eid, cn)
    while eid do
        local e = world[eid]
        local c = e[cn]
        if c then
            return c
        end
        eid = e.parent
    end
end

function ies_class.filter_list(eid)
    local fs = ies.full_state(eid)
    local filters = {}
    for _, eid in world:each "primitive_filter" do
        local pf = world[eid].primitive_filter
        filters[pf.filter_type] = pf
    end

    local l = {}
    for n, mask in pairs(STATE_TYPE) do
		if (fs & mask) ~= 0 then
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