local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"

local irender   = world:interface "ant.render|irender"
local imaterial = world:interface "ant.asset|imaterial"

local pickup_materials = {}

local function packeid_as_rgba(eid)
    return {(eid & 0x000000ff) / 0xff,
            ((eid & 0x0000ff00) >> 8) / 0xff,
            ((eid & 0x00ff0000) >> 16) / 0xff,
            ((eid & 0xff000000) >> 24) / 0xff}    -- rgba
end

local uid_cache = {}
local function get_properties(eid, fx)
	local p = uid_cache[eid]
	if p then
		return p
	end
	local imaterial = world:interface "ant.asset|imaterial"
	local v = math3d.ref(math3d.vector(packeid_as_rgba(eid)))
	local u = fx.uniforms[1]
	assert(u.name == "u_id")
	p = {
		u_id = {
			value = v,
			handle = u.handle,
			type = u.type,
			set = imaterial.property_set_func "u"
		},
	}
	uid_cache[eid] = p
	return p
end

local s = ecs.system "pickup_primitive_system"

function s:init()
    pickup_materials.opacity	= imaterial.load '/pkg/ant.resources/materials/pickup_opacity.material'
	pickup_materials.translucent= imaterial.load '/pkg/ant.resources/materials/pickup_transparent.material'
end

function s:end_filter()
	for e in w:select "filter_result:in render_object:in eid:in filter_material:out" do
		local eid = e.eid
		local fr = e.filter_result
		local st = e.render_object.fx.setting.surfacetype
		local fm = e.filter_material
		local qe = w:singleton("pickup_queue", "primitive_filter:in")
		for _, fn in ipairs(qe.primitive_filter) do
			if fr[fn] then
				local m = assert(pickup_materials[st])
				local state = e.render_object.state
				fm[fn] = {
					fx			= m.fx,
					properties	= get_properties(eid, m.fx),
					state		= irender.check_primitive_mode_state(state, m.state),
				}
			end
		end
	end
end