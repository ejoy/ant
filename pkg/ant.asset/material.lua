local ecs	= ...
local world = ecs.world
local w		= world.w

local assetmgr		= require "main"
local bgfx			= require "bgfx"

local RM			= ecs.require "ant.material|material"

local imaterial = {}

function imaterial.set_property(e, who, what, mattype)
	w:extend(e, "filter_material:in")
	local fm = e.filter_material
	mattype = mattype or "main_queue"
	fm[mattype][who] = what
end

function imaterial.instance_material(filename)
	local r = assetmgr.resource(filename)
    return RM.create_instance(r.object)
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

local ms = ecs.system "material_system"
function ms:component_init()
	w:clear "material_result"

	for e in w:select "INIT material:in material_result:new" do
		e.material_result = assetmgr.resource(e.material)
	end
end

return imaterial
