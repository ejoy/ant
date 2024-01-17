local ecs = ...
local world = ecs.world
local w = world.w

local ivs = {}

function ivs.has_state(e, name)
	w:extend(e, "visible_state:in")
	local vs = e.visible_state
	if name == "main_view" then
		return vs.main_queue
	elseif name == "selectable" then
		return vs.pickup_queue
	elseif name == "cast_shadow" then
		return vs.csm1_queue or
		vs.csm2_queue or
		vs.csm3_queue or
		vs.csm4_queue
	else
		return vs[name]
	end
end

local function set_visible_states(vs, s, v)
	for n in s:gmatch "[%w_]+" do
		if n == "main_view" then
			vs["main_queue"] = v
			vs["pre_depth_queue"] = v
		elseif n == "selectable" then
			vs["pickup_queue"] = v
		elseif n == "cast_shadow" then
			vs["csm1_queue"] = v
			vs["csm2_queue"] = v
			vs["csm3_queue"] = v
			vs["csm4_queue"] = v
		end

		vs[n] = v
	end
end

function ivs.build_state(vs)
	local result = {}
	if vs["main_queue"] or vs["pre_depth_queue"] then
		result[#result+1] = "main_view"
	end
	if vs["pickup_queue"] then
		result[#result+1] = "selectable"
	end
	if vs["csm1_queue"] or vs["csm2_queue"] or vs["csm3_queue"] or vs["csm4_queue"] then
		result[#result+1] = "cast_shadow"
	end
	return table.concat(result, '|')
end

function ivs.set_state(e, name, v)
	w:extend(e, "visible_state:in visible_state_changed?out")
	set_visible_states(e.visible_state, name, v)
	e.visible_state_changed = true
	w:submit(e)
end

local m = ecs.system "visible_state_system"

function m:component_init()
    for e in w:select "INIT visible_state:update" do
		local vs = {}
		set_visible_states(vs, e.visible_state, true)
        e.visible_state = vs
    end
end

function m:finish_scene_update()
	w:clear "visible_state_changed"
end

return ivs
