local ecs	= ...
local world = ecs.world
local w		= world.w

local assetmgr	= require "main"
local bgfx		= require "bgfx"

local RM		= ecs.require "ant.material|material"
local L			= import_package "ant.render.core".layout

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

function ms:entity_init()
	for e in w:select "INIT mesh:in material:in" do
		local declname = e.mesh.vb.declname
		if e.mesh.vb2 then
			declname = ("%s|%s"):format(declname, e.mesh.vb2.declname)
		end

		local matres = assetmgr.resource(e.material)
		local varyings = matres.fx.varyings

		if varyings then
			varyings = L.parse_varyings(varyings)
			local inputs = L.parse_varyings(L.varying_inputs(declname))
			for k, v in pairs(varyings) do
				if k:match "a_" then
					local function is_input_equal(lhs, rhs)
						return lhs.type == rhs.type and lhs.bind == rhs.bind
					end
					if not (inputs[k] and is_input_equal(inputs[k], v)) then
						error(("Layout:%s decal is not equal"):format(k))
					end
				end
			end
		end
	end
end

return imaterial
