local util = {}
util.__index = util

local asset = require "asset"
local common_util = require "common.util"
local mu = require "math.util"

function util.load_mesh(entity)
	local mesh_comp = entity.mesh
	local filename = mesh_comp.path

	local assetinfo = asset.load(filename)
	mesh_comp.assetinfo = assetinfo			
end

function util.load_material(entity)			
	local material_comp = entity.material

	local content = material_comp.content
	for _, m in ipairs(content) do
		local filename = m.path
		local materialinfo = asset.load(filename)
		m.materialinfo = materialinfo

		--
		local properties = assert(m.properties)	
		local asset_properties = materialinfo.properties
		if asset_properties then
			for k, v in pairs(asset_properties) do
				properties[k] = {name=v.name, type=v.type, value=common_util.deep_copy(v.default)}
			end
		end
	end
end

function util.create_render_entity(ms, world, name, meshfile, materialfile)
	local eid = world:new_entity("scale", "rotation", "position",
	"mesh", "material",
	"name",
	"can_select", "can_render")

	local obj = world[eid]
	mu.identify_transform(ms, obj)
	
	obj.name.n = name

	obj.mesh.path = meshfile
	util.load_mesh(obj)		

	obj.material.content[1] = {path=materialfile, properties={}}
	util.load_material(obj)
	return eid
end

function util.create_hierarchy_entity(ms, world, name)
	local h_eid = world:new_entity("scale", "rotation", "position",
	"editable_hierarchy", "hierarchy_name_mapper", 
	"name")

	local obj = world[h_eid]
	obj.name.n = name

	mu.identify_transform(ms, obj)
	return h_eid
end

return util