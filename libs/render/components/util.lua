local util = {}
util.__index = util

local asset = require "asset"
local common_util = require "common.util"
local mu = require "math.util"


local function load_res(comp, respath, param, errmsg)
	if respath then
		comp.ref_path = respath
	end

	local ref_path = comp.ref_path
	if ref_path == nil then
		error(string.format("[%s]load resource failed, need ref_path, but get nil", errmsg))
	end

	comp.assetinfo = asset.load(ref_path, param)
end

function util.load_skeleton(entity, respath, param)
	load_res(entity.skeleton, respath, param, "load.skeleton")	
end

function util.load_animation(entity, respath, param)
	load_res(entity.animation, respath, param, "load.animation")
end

function util.new_sampling_cache(num_joints)
	local animodule = require "hierarchy.animation"		
	return animodule.new_sampling(num_joints)
end

function util.load_mesh(entity, respath, param)
	load_res(entity.mesh, respath, param, "load.mesh")
end

function util.load_texture(name, stage, texpath)	
	assert(type(texpath) == "string", "texture type's default value should be path to texture file")
	local assetinfo = asset.load(texpath)
	return {name=name, type="texture", stage=stage, value=assetinfo.handle}
end


function util.update_properties(dst_properties, src_properties)		
	for k, v in pairs(src_properties) do
		if v.type == "texture" then
			dst_properties[k] = util.load_texture(v.name, v.stage, v.default or v.path)
		else
			dst_properties[k] = {name=v.name, type=v.type, value=common_util.deep_copy(v.default or v.value)}
		end
	end
end

function util.load_materialex(content)
	for _, m in ipairs(content) do		
		local materialinfo = asset.load(m.path)
		m.materialinfo = materialinfo
	
		--
		local properties = materialinfo.properties
		if properties then
			util.update_properties(assert(m.properties), properties)
		end
	end
	return content
end

-- todo : remove this function by load_materialex
function util.load_material(entity, material_filenames)
	if material_filenames then
		for idx, f in ipairs(material_filenames) do
			entity.material.content[idx] = {path = f, properties = {}}
		end
	end

	util.load_materialex(entity.material.content)
end

function util.create_render_entity(ms, world, name, meshfile, materialfile)
	local eid = world:new_entity("scale", "rotation", "position",
	"mesh", "material",
	"name",
	"can_select", "can_render")

	local obj = world[eid]
	mu.identify_transform(ms, obj)
	
	obj.name.n = name

	obj.mesh.ref_path = meshfile
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

function util.is_entity_visible(entity)
	local can_render = entity.can_render
	if can_render then
		if can_render.visible then
			return entity.mesh ~= nil
		end		
	end

	return false
end

return util