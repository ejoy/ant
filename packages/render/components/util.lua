local util = {}
util.__index = util

local bgfx = require "bgfx"
local fs = require "filesystem"

local asset = import_package "ant.asset"
local mu = import_package "ant.math".util
local declmgr = require "vertexdecl_mgr"

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

function util.load_texture(name, stage, filename)	
	assert(type(filename) == "table", "texture type's default value should be path to texture file")
	local assetinfo = asset.load(filename)
	return {name=name, type="texture", stage=stage, ref_path=filename, handle=assetinfo.handle}
end

function util.add_material(material, filename)
	local content = material.content
	if content == nil then
        content = {}
        material.content = content
    end

	local item = {
		ref_path = filename,
	}
	util.create_material(item)
    content[#content + 1] = item
end

local function update_properties(dst_properties, src_properties)
	local srctextures = src_properties.textures
	if srctextures then
		local dsttextures = dst_properties.textures or {}
		for k, v in pairs(srctextures) do
			local tex = dsttextures[k]
			if tex == nil then
				tex = {name=v.name, type=v.type, stage=v.stage, ref_path=fs.path(v.ref_path)}
				dsttextures[k] = tex
			end

			local refpath = tex.ref_path
			if refpath then
				tex.handle = asset.load(refpath).handle
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
	local materialinfo = asset.load(material.ref_path)
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

function util.assign_material(filepath)
	return {
		content = {
			{ref_path = filepath}
		}
	}
end


-- content:material_content
-- texture_tbl:{
--  s_basecolor = {type="texture", name="base color", stage=0, ref_path={"ant.resources", "PVPScene/siegeweapon_d.texture"}},
--  s_normal = {type="texture", name="normal", stage=1, ref_path={"ant.resources", "PVPScene/siegeweapon_n.texture"}},
-- },
function util.change_textures(content, texture_tbl)
    content.properties = content.properties or {}
    local textures = content.properties.textures or {}
    for name, tex in pairs(texture_tbl) do
        textures[name] = util.load_texture(
            tex.name,
            tex.stage,
            tex.ref_path
        )
    end
    content.properties.textures = textures
    -- todo:modify materialinfo ?
    -- if content.materialinfo.properties and content.materialinfo.properties.texture then
    --  content.materialinfo = deep_copy(content.materialinfo)
end

function util.is_entity_visible(entity)
    local can_render = entity.can_render
    if can_render then
        local mesh = entity.mesh
        return mesh and mesh.assetinfo
    end

    return false
end

function util.create_mesh_handle(meshdesc, accessors, bvs, buffers)
	local scene = {
			scene = 0,
			scenes = {nodes = {0},},
			nodes = {mesh=0},
			meshes = meshdesc,
			accessors = accessors,
			bufferViews = bvs,
			buffers = buffers,
		}
	
	local ml = import_package "ant.modelloader"
	local mlutil = ml.util
	mlutil.init_scene(scene)
	return {handle = scene,}
end

function util.create_grid_entity(world, name, w, h, unit, view_tag)
    local geopkg = import_package "ant.geometry"
    local geolib = geopkg.geometry

	local gridid = world:create_entity {
		transform = mu.identity_transform(),
        mesh = {},
        material = util.assign_material(fs.path "//ant.resources" / "materials" / "line.material"),
		name = name,
		can_render = true,
		main_view = true,
    }
    local grid = world[gridid]
    if view_tag then world:add_component(gridid, view_tag, true) end
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

	--grid.mesh.assetinfo = util.create_mesh_handle(declmgr.get("p3|c40niu").handle, gvb, ib)
	local meshdesc = {
		primitives = {
			{
				attributes = {
					POSITION = 1,
					COLOR_0 = 2,
				},
				indices = 0,
			},
		},
	}

	local num_verites = #vb
	local num_indices = #ib
	local stride = 16 -- "fffd"

	local gltfutil = import_package "ant.glTF".util
	local accessors = gltfutil.generate_accessors {
		{0, "UNSIGNED_SHORT", "SCALAR", 0, num_indices},
		{1, "FLOAT", "VEC3", 0, num_verites,},
		{1, "UNSIGNED_BYTE", "VEC4", 12, num_verites},
	}
	
	local bufferviews = gltfutil.generate_bufferviews {
		{0, 0, num_indices * 2, 0, "index",},
		{1, 0, num_verites * stride, stride, "vertex"},
	}

	local buffers = {
		{
			byteLength = stride * num_verites,
			extras = {data = gvb,},
		},
		{
			byteLength = num_indices * 2,
			extras = {data = ib,}
		}
	}

	grid.mesh.assetinfo = util.create_mesh_handle(meshdesc, accessors, bvs, buffers)
    return gridid
end

function util.create_plane_entity(world, color, size, pos, name)
	return world:create_entity {
		transform = {
			s = size or {0.08, 0.005, 0.08},
			r = {0, 0, 0, 0},
			t = pos or {0, 0, 0, 1}
		},
		mesh = {
			ref_path = fs.path "//ant.resources/depiction/cube.mesh"
		},
		material = {
			content = {
				{
					ref_path = fs.path "//ant.resources/depiction/shadow/mesh_receive_shadow.material",
					properties = {
						uniforms = {
							u_color = {type="color", name="color", value=color}
						},
					}
				}
			}
		},
		can_render = true,
		--can_cast = true,
		main_view = true,
		name = name or "Plane",
	}
end

local function get_quaddecl()
	return declmgr.get("p3|t2")
end

local function quad_mesh(vb)
	local stride = 20
	return util.create_mesh_handle({primitives = {{attributes = {POSITION=0, TEXCOORD_0=1}}}}, 
		gltfutil.generate_accessors {
			{0, "FLOAT", "VEC3", 0, 4, false},
			{1, "FLOAT", "VEC2", 12, 4, false},
		},
		gltfutil.generate_bufferviews {
			{0, 0, 4 * stride, stride, "vertex"}
		},
		{{byteLength = stride * 4, extras = {data=vb},}})
end

function util.quad_mesh(rect)
	local vb = 	{
		"fffff",
		rect.x, 		 rect.y, 			0, 	0, 1,	--bottom left
		rect.x, 		 rect.y + rect.h, 	0, 	0, 0,	--top left
		rect.x + rect.w, rect.y, 			0, 	1, 1,	--bottom right
		rect.x + rect.w, rect.y + rect.h, 	0, 	1, 0,	--top right
	}

	return quad_mesh(vb)
end

function util.create_shadow_quad_entity(world, rect, name)
	local eid = world:create_entity {
		transform = {
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		mesh = {},
		material = {
			content = {{
				ref_path = fs.path "//ant.resources/depiction/shadowmap_quad.material",
			}}
		},
		can_render = true,
		main_view = true,
		name = name or "quad",
	}

	local e = world[eid]
	e.mesh.assetinfo = util.quad_mesh(rect)
	return eid
end

function util.create_quad_entity(world, texture_tbl, view_tag, name)
    local quadid = world:create_entity{
        transform = mu.identity_transform(),
        can_render = true,
        mesh = {},
        material = util.assign_material(fs.path "//ant.resources/materials/texture.material"),
        name = name,
    }
    local quad = world[quadid]
    if view_tag then world:add_component(quadid, view_tag, true) end
    util.change_textures(quad.material.content[1], texture_tbl)

	local vb = {
		"fffff",
		-3,  3, 0, 0, 0,
		 3,  3, 0, 1, 0,
		-3, -3, 0, 0, 1,
		 3, -3, 0, 1, 1,
	}
    
    quad.mesh.assetinfo = quad_mesh(vb)
    return quadid
end


function util.create_dynamic_mesh_handle(attributes, vbsize, ibsize)
	return {
		handle = {
			bufferViews = {
				handle = bgfx.create_dynamic_vertex_buffer(vbsize, decl, "a"),
				byteOffset = 0,
				byteLength = vbsize,
				

			}
			-- groups = {
			-- 	{
			-- 		vb = {handles = {bgfx.create_dynamic_vertex_buffer(vbsize, decl, "a")}},
			-- 		ib = ibsize and {handle= bgfx.create_dynamic_index_buffer(ibsize, "a")} or nil,
			-- 		primitives = {},
			-- 	}
			-- }
		}
	}
end

return util