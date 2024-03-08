local ecs	= ...
local world = ecs.world
local w		= world.w

local RM		= ecs.require "ant.material|material"
local queuemgr  = ecs.require "queue_mgr"
local imaterial = {}

local DEFAULT_MATERIAL_IDX<const> = queuemgr.default_material_index()

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

assert(RM.system_attrib_update == nil, "'system_attrib_update' should not ready")
function imaterial.system_attrib_update(...)
	return RM.system_attrib_update(...)
end

return imaterial
