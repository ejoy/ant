local ecs	= ...
local world = ecs.world
local w		= world.w

local bgfx		= require "bgfx"

local RM		= ecs.require "ant.material|material"
local imaterial = {}

--TODO: need move to ant.render package
local DEFAULT_MATERIAL_IDX<const> = 0 --same with queue_mgr in ant.render
function imaterial.default_material_index()
	return DEFAULT_MATERIAL_IDX
end

local function tomi(e, midx)
	w:extend(e, "filter_material:in")
	local fm = e.filter_material
	midx = midx or DEFAULT_MATERIAL_IDX
	return fm[midx]
end

function imaterial.set_property(e, who, what, midx)
	local mi = tomi(e, midx)
	mi[who] = what
end

function imaterial.set_state(e, state, midx)
	local mi = tomi(e, midx)
	return mi:set_state(bgfx.make_state(state))
end

assert(RM.system_attrib_update == nil, "'system_attrib_update' should not ready")
function imaterial.system_attrib_update(...)
	return RM.system_attrib_update(...)
end

return imaterial
