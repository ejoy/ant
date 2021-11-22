local ecs = ...
local world = ecs.world
local w = world.w

local STATE_TYPE = {
	---
	main_view 	= 0x00000001,
	cast_shadow	= 0x00000002,
	selectable	= 0x00000004,

	--
	lightmap	= 0x00000010,
	--
	postprocess_obj = 0x00000020,
	ldr			= 0x00000040,
	--
	auxgeom		= 0x00008000,
}

local function filter_mask(names)
	local s = 0
	for name in names:gmatch "[%w_]+" do
		s = s | STATE_TYPE[name]
	end
	return s
end

local ifs = ecs.interface "ifilter_state"

ifs.filter_mask = filter_mask

local function get_ro(e)
	w:sync("render_object:in", e)
	return e.render_object
end

function ifs.has_state(e, name)
	return ((get_ro(e).filter_state) & STATE_TYPE[name]) ~= 0
end

function ifs.set_state(e, name, v)
	local ro = get_ro(e)
	if not ro or not ro.filter_state then
		return
	end
	ro.filter_state = v and
		(ro.filter_state | STATE_TYPE[name]) or
		(ro.filter_state & (~STATE_TYPE[name]))
	e.render_object_update = true
	w:sync("render_object_update?out", e)
end

function ifs.state_names(statemask)
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
    for e in w:select "INIT filter_state:in render_object:in" do
        e.render_object.filter_state = filter_mask(e.filter_state) or 0
    end
end