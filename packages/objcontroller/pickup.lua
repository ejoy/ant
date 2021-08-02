local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"

local irender   = world:interface "ant.render|irender"
local imaterial = world:interface "ant.asset|imaterial"

w:register "pickup_queue_opacity"
w:register "pickup_queue_opacity_cull"
w:register "pickup_queue_translucent"
w:register "pickup_queue_translucent_cull"

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

function s:update_filter()
    for v in w:select "render_object_update render_object:in eid:in filter_material:in" do
        local rc = v.render_object
		local st = rc.fx.setting.surfacetype
        local state = rc.entity_state
		local eid = v.eid

		local tag = "pickup_queue_" .. st
		local sync = tag .. "?out"
		for vv in w:select(tag .. " primitive_filter:in") do
			local pf = vv.primitive_filter
			local mask = ies.filter_mask(pf.filter_type)
			local exclude_mask = pf.exclude_type and ies.filter_mask(pf.exclude_type) or 0

			local add = ((state & mask) ~= 0) and ((state & exclude_mask) == 0)
			--ipf.update_filter_tag("pickup_queue", st, add, v)
			v[tag] = add
			w:sync(sync, v)
			local m = assert(pickup_materials[st])
			v.filter_material[st] = add and {
				fx = m.fx,
				properties = get_properties(eid, m.fx),
				state = irender.check_primitive_mode_state(rc.state, m.state),
			} or nil
		end

    end
end

function s:render_submit()
    for v in w:select "pickup_queue visible render_target:in" do
        local rt = v.render_target
        local viewid = rt.viewid

		for vv in w:select "pickup_queue_opacity render_object:in filter_material:in pickup_queue_opacity_cull:absent" do
			irender.draw(viewid, vv.render_object, vv.filter_material["opacity"])
		end

		for vv in w:select "pickup_queue_translucent render_object:in filter_material:in pickup_queue_translucent_cull:absent" do
			irender.draw(viewid, vv.render_object, vv.filter_material["translucent"])
		end
    end
end