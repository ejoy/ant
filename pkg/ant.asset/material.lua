local ecs	= ...
local world = ecs.world
local w		= world.w

local assetmgr	= require "main"
local bgfx		= require "bgfx"

local RM		= ecs.require "ant.material|material"
local imaterial = {}

local DEFAULT_MATERIAL_IDX<const> = 0 --same with queue_mgr in ant.render

function imaterial.set_property(e, who, what, midx)
	w:extend(e, "filter_material:in")
	local fm = e.filter_material
	midx = midx or DEFAULT_MATERIAL_IDX
	fm[midx][who] = what
end

function imaterial.default_material_index()
	return DEFAULT_MATERIAL_IDX
end

assert(RM.system_attrib_update == nil, "'system_attrib_update' should not ready")
function imaterial.system_attrib_update(...)
	return RM.system_attrib_update(...)
end

function imaterial.set_state(e, state)
	w:extend(e, "filter_material:in")
	local fm = e.filter_material
	return fm.main_queue:set_state(bgfx.make_state(state))
end

return imaterial
