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

local function load_res(comp, pkgname, respath, param, errmsg)
	local res = asset.load(pkgname, respath, param)	
	if res == nil then
		error(string.format("[%s]load resource failed, pkgname:%s, respath:%s", errmsg, pkgname, respath))
	end

	comp.assetinfo = res
	comp.ref_path = {
		package = pkgname,
		filename = respath,
	}
end

function util.load_skeleton(comp, pkgname, respath, param)
	load_res(comp, pkgname, respath, param, "load.skeleton")	
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

function util.load_skinning_mesh(smcomp, meshcomp, pkgname, respath, param)
	load_res(smcomp, pkgname, respath, param, "load.skinning_mesh")
	meshcomp.assetinfo = gen_mesh_assetinfo(smcomp)
end

function util.load_mesh(comp, pkgname, respath, param)
	load_res(comp, pkgname, respath, param, "load.mesh")
end

function util.load_texture(name, stage, pkgname, texpath)	
	assert(type(texpath) ~= "string", "texture type's default value should be path to texture file")
	local assetinfo = asset.load(pkgname, texpath)
	return {name=name, type="texture", stage=stage, ref_path={package=pkgname, filename=texpath}, handle=assetinfo.handle}
end

function util.add_material(material, pkgname, respath)
	local content = material.content
	if content == nil then
		content = {}
		material.content = content
	end

	local item = {
		ref_path = {
			package = pkgname,
			filename = respath,
		},
	}
	util.create_material(item)
	content[#content+1] = item
end

local function update_properties(dst_properties, src_properties)
	local srctextures = src_properties.textures
	if srctextures then
		local dsttextures = dst_properties.textures or {}
		for k, v in pairs(srctextures) do
			local refpath = v.ref_path
			local tex = util.load_texture(v.name, v.stage, refpath[1], fs.path(refpath[2]))
			if dsttextures[k] == nil then
				dsttextures[k] = tex
			else
				dsttextures[k].handle = tex.handle
			end
		end
		dst_properties.textures = dsttextures
	end

	local srcuniforms = src_properties.uniforms
	if srcuniforms then
		local dstuniforms = dst_properties.uniforms or {}
		for k, v in pairs(srcuniforms) do			
			if dstuniforms[k] == nil then
				assert(type(v.default) == "table")			
				local value = deep_copy(v.default)
				dstuniforms[k] = {name=v.name, type=v.type, value=value}
			end
		end
		dst_properties.uniforms = dstuniforms
	end
end

function util.create_material(material)
	local materialinfo = asset.load(material.ref_path.package, material.ref_path.filename)
	if not material.properties then
		material.properties = {}
	end
	local mproperties = materialinfo.properties 
	local properties = material.properties
	if mproperties then
		update_properties(properties, mproperties)
	end
	material.materialinfo = materialinfo	
end

function util.create_render_entity(world, name, meshfile, materialfile)
	local eid = world:create_entity {
		scale = {0,0,0,0},
		rotation = {0,0,0,0},
		position = {0,0,0,0},
		mesh = {},
		material = {},
		name = "",
		can_select = true,
		can_render = true,
	}

	local obj = world[eid]
	mu.identify_transform(obj)
	
	obj.name = name
	local pkgname, respath = meshfile[1], meshfile[2]
	util.load_mesh(obj.mesh, pkgname, respath)
	local mpkgname, mrespath = materialfile[1], materialfile[2]
	util.add_material(obj.material, mpkgname, mrespath)
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

	util.add_material(grid.material, "ant.resources", fs.path "line.material")

	return gridid
end

return util