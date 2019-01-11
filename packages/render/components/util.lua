local util = {}
util.__index = util

local bgfx = require "bgfx"
local fs = require "filesystem"

local asset = import_package "ant.asset"
local math = import_package "ant.math"
local mu = math.util


local function deep_copy(t)
	if type(t) == "table" then
		local tmp = {}
		for k, v in pairs(t) do
			tmp[k] = deep_copy(v)
		end
		return tmp
	end
	return t
end

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

local function gen_mesh_assetinfo(skinning_mesh_comp)
	local modelloader = import_package "ant.modelloader"

	local skinning_mesh = skinning_mesh_comp.assetinfo.handle

	local decls = {}
	local vb_handles = {}
	local vb_data = {"!", "", 1}
	for _, type in ipairs {"dynamic", "static"} do
		local layout = skinning_mesh:layout(type)
		local decl = modelloader.create_decl(layout)
		table.insert(decls, decl)

		local buffer, size = skinning_mesh:buffer(type)
		vb_data[2], vb_data[3] = buffer, size
		if type == "dynamic" then
			table.insert(vb_handles, bgfx.create_dynamic_vertex_buffer(vb_data, decl))
		elseif type == "static" then
			table.insert(vb_handles, bgfx.create_vertex_buffer(vb_data, decl))
		end
	end

	local function create_idx_buffer()
		local idx_buffer, ib_size = skinning_mesh:index_buffer()	
		if idx_buffer then			
			return bgfx.create_index_buffer({idx_buffer, ib_size})
		end

		return nil
	end

	local ib_handle = create_idx_buffer()

	return {
		handle = {
			groups = {
				{
					bounding = skinning_mesh:bounding(),
					vb = {
						decls = decls,
						handles = vb_handles,
					},
					ib = {
						handle = ib_handle,
					}
				}
			}
		},			
	}
end

function util.load_skinning_mesh(smcomp, meshcomp, respath, param)
	load_res(smcomp, respath, param, "load.skinning_mesh")
	meshcomp.assetinfo = gen_mesh_assetinfo(smcomp)
end

function util.load_mesh(comp, respath, param)
	load_res(comp, respath, param, "load.mesh")
end

function util.load_texture(name, stage, texpath)	
	assert(type(texpath) == "userdata", "texture type's default value should be path to texture file")
	local assetinfo = asset.load(texpath)
	return {name=name, type="texture", stage=stage, value=assetinfo.handle}
end


function util.update_properties(dst_properties, src_properties)		
	for k, v in pairs(src_properties) do
		if v.type == "texture" then
			dst_properties[k] = util.load_texture(v.name, v.stage, fs.path(v.default or v.path))
		else
			dst_properties[k] = {name=v.name, type=v.type, value=deep_copy(v.default or v.value)}
		end
	end
end

function util.create_material(filepath, info)
	local materialinfo = asset.load(filepath)
	--
	local mproperties = materialinfo.properties 
	local properties = nil
	if mproperties then
		properties = {}
		util.update_properties(properties, mproperties)
	end
	info.path = filepath
	info.materialinfo = materialinfo
	info.properties = properties
end

function util.load_materialex(content)
	for _, m in ipairs(content) do
		util.create_material(m.path, m)
		if m.properties == nil then
			m.properties = {}
		end
	end
	return content
end

-- todo : remove this function by load_materialex
function util.load_material(material, material_filenames)
	if material_filenames then
		if material.content == nil then
			material.content = {}
		end
		for idx, f in ipairs(material_filenames) do
			material.content[idx] = {path = f, properties = {}}
		end
	end

	util.load_materialex(material.content)
end

function util.create_render_entity(world, name, meshfile, materialfile)
	local eid = world:new_entity("scale", "rotation", "position",
	"mesh", "material",
	"name",
	"can_select", "can_render")

	local obj = world[eid]
	mu.identify_transform(obj)
	
	obj.name = name
	util.load_mesh(obj.mesh, meshfile)
	util.load_material(obj.material, {materialfile})
	return eid
end

function util.create_hierarchy_entity(world, name)
	local h_eid = world:new_entity("scale", "rotation", "position",
	"editable_hierarchy", "hierarchy_name_mapper", 
	"name")

	local obj = world[h_eid]
	obj.name = name

	mu.identify_transform(obj)
	return h_eid
end

function util.is_entity_visible(entity)
	local can_render = entity.can_render
	if can_render then
		local mesh = entity.mesh
		return mesh and mesh.assetinfo
	end

	return false
end

function util.create_mesh_handle(decl, vb, ib)
	local groups = {}
	
	if type(decl) == "table" then
		assert("not implement")
	else
		local group = {
			vb = {
				decls={decl}, 
				handles={bgfx.create_vertex_buffer(vb, decl)},
			},			
		}

		if ib then
			group.ib = {handle = bgfx.create_index_buffer(ib)}
		end

		table.insert(groups, group)
	end

	return {handle={groups = groups}}
end

function util.create_grid_entity(world, name, w, h, unit)
	local geopkg= import_package "ant.geometry"
	local geolib= geopkg.geometry

	local gridid = world:new_entity(
		"rotation", "position", "scale", 
		"can_render", "mesh", "material",
		"name"
	)
    local grid = world[gridid]
    grid.name = name or "grid"
	mu.identify_transform(grid)
	w = w or 64
	h = h or 64
	unit = unit or 1
	local vb, ib = geolib.grid(w, h, unit)
	local gvb = {"fffd"}
	for _, v in ipairs(vb) do
		for _, vv in ipairs(v) do
			table.insert(gvb, vv)
		end
	end

    local vdecl = bgfx.vertex_decl {
        { "POSITION", 3, "FLOAT" },
        { "COLOR0", 4, "UINT8", true }
    }

	grid.mesh.ref_path = ""
    grid.mesh.assetinfo = util.create_mesh_handle(vdecl, gvb, ib)

	util.load_material(grid.material, {fs.path "line.material"})

	return gridid
end

return util