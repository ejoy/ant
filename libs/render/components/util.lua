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

function util.load_skeleton(comp, respath, param)
	load_res(comp, respath, param, "load.skeleton")	
end

function util.load_animation(comp, skeleton, respath, param)
	load_res(comp, respath, param, "load.animation")
	do
		local skehandle = assert(skeleton.assetinfo.handle)
		local numjoints = #skehandle
		comp.sampling_cache = util.new_sampling_cache(#skehandle)

		local anihandle = comp.assetinfo.handle
		anihandle:resize(numjoints)
	end
end

function util.load_skinning_mesh(comp, respath, param)
	load_res(comp, respath, param, "load.skinning_mesh")
end

function util.load_mesh(comp, respath, param)
	load_res(comp, respath, param, "load.mesh")
end

function util.new_sampling_cache(num_joints)
	local animodule = require "hierarchy.animation"		
	return animodule.new_sampling_cache(num_joints)
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

function util.create_material(filepath)
	local materialinfo = asset.load(filepath)
	--
	local mproperties = materialinfo.properties 
	local properties = nil
	if mproperties then
		properties = {}
		util.update_properties(properties, mproperties)
	end
	
	return {path=filepath, materialinfo=materialinfo, properties=properties}
end

function util.load_materialex(content)
	for _, m in ipairs(content) do
		local info = util.create_material(m.path)
		if info.properties then
			for k, p in pairs(info.properties) do
				m.properties[k] = p
			end
		end
	end
	return content
end

-- todo : remove this function by load_materialex
function util.load_material(material, material_filenames)
	if material_filenames then
		for idx, f in ipairs(material_filenames) do
			material.content[idx] = {path = f, properties = {}}
		end
	end

	util.load_materialex(material.content)
end

function util.create_render_entity(ms, world, name, meshfile, materialfile)
	local eid = world:new_entity("scale", "rotation", "position",
	"mesh", "material",
	"name",
	"can_select", "can_render")

	local obj = world[eid]
	mu.identify_transform(ms, obj)
	
	obj.name = name

	obj.mesh.ref_path = meshfile
	util.load_mesh(obj.mesh)		

	obj.material.content[1] = {path=materialfile, properties={}}
	util.load_material(obj.material)
	return eid
end

function util.create_hierarchy_entity(ms, world, name)
	local h_eid = world:new_entity("scale", "rotation", "position",
	"editable_hierarchy", "hierarchy_name_mapper", 
	"name")

	local obj = world[h_eid]
	obj.name = name

	mu.identify_transform(ms, obj)
	return h_eid
end

function util.is_entity_visible(entity)
	local can_render = entity.can_render
	if can_render then
		return entity.mesh ~= nil		
	end

	return false
end

return util