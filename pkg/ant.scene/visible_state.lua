local ecs = ...
local world = ecs.world
local w = world.w

local STATE_TYPE = {
---
	main_view 		= 0x00000001,
	cast_shadow		= 0x00000002,
	selectable		= 0x00000004,
	postprocess_obj = 0x00000008,
	--
	lightmap		= 0x00000010,
	--
	auxgeom			= 0x00008000,
}

local function filter_mask(names)
	local s = 0
	for name in names:gmatch "[%w_]+" do
		s = s | STATE_TYPE[name]
	end
	return s
end

local ivs = ecs.interface "ivisible_state"

ivs.filter_mask = filter_mask

function ivs.has_state(e, name)
	return ((e.visible_state) & STATE_TYPE[name]) ~= 0
end

function ivs.set_state(e, name, v)
	w:extend(e, "visible_state?update render_object_update?out")
	local fs = e.visible_state
	if fs then
		e.visible_state = v and
		(fs | STATE_TYPE[name]) or
		(fs & (~STATE_TYPE[name]))
		e.render_object_update = true
	end
end

function ivs.state_names(statemask)
	local n = {}
	for k, v in pairs(STATE_TYPE) do
		if (v & statemask) ~= 0 then
			n[#n+1] = k
		end
	end

	return table.concat(n, '|')
end
local m = ecs.system "filter_state_system"
function m:entity_init()
    for e in w:select "INIT visible_state:update" do
        e.visible_state = filter_mask(e.visible_state)
    end
end