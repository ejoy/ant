local ecs = ...
local world = ecs.world
local w = world.w

--TODO: entity state will determine where render entity should pushed in which render queue.
--		but right now, 'visible' state not only determine entity should push in main render queue
--      but also mark an entity visible or not. so 'visible' state should call 'mainview'
--      denote that it will push in mainview queue, and add another var to denote whether this
--      entity visible or not.

local STATE_TYPE = {
	---
	visible 	= 0x00000001,
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

local ies = ecs.interface "ientity_state"

local function get_rc(e)
	w:sync("render_object:in", e)
	return e.render_object
end

function ies.has_state(e, name)
	return ((get_rc(e).entity_state) & STATE_TYPE[name]) ~= 0
end

function ies.set_state(e, name, v)
	local rc = get_rc(e)
	if not rc or not rc.entity_state then
		return
	end
	if v then
		rc.entity_state = rc.entity_state | STATE_TYPE[name]
	else
		rc.entity_state = rc.entity_state & (~STATE_TYPE[name])
	end
	e.render_object_update = true
	w:sync("render_object_update?out", e)
end

function ies.can_visible(e)
	return ies.has_state(e, "visible")
end

function ies.can_cast(e)
	return ies.has_state(e, "cast_shadow")
end

function ies.can_select(e)
	return ies.has_state(e, "selectable")
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

ies.filter_mask = filter_mask
function ies.state_names(statemask)
	local n = {}
	for k, v in pairs(STATE_TYPE) do
		if v & statemask then
			n[#n+1] = k
		end
	end

	return table.concat(n, '|')
end
local m = ecs.system "entity_state_system"
function m:entity_init()
    for e in w:select "INIT state:in render_object:in" do
        local s = e.state
        if type(s) == "string" then
            s = ies.filter_mask(s)
        end
        e.render_object.entity_state = s or 0
    end
end