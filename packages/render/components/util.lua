local util = {}
util.__index = util

local fs = require "filesystem"

local asset = import_package "ant.asset".mgr
local mu = import_package "ant.math".util
local bgfx = require "bgfx"
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

function util.assign_material(filepath, properties)
	return {
		content = {
			{ref_path = filepath, properties = properties}
		}
	}
end

function util.create_submesh_item(material_refs)
	return {material_refs=material_refs, visible=true}
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

function util.create_simple_mesh(vertex_desc, vb, num_vertices, ib, num_indices)
	local group = {
		vb = {
			handles = {
				bgfx.create_vertex_buffer(vb, declmgr.get(vertex_desc).handle),
			},
			start = 0, num = num_vertices,
		},
		ib = ib and {
			handle = bgfx.create_index_buffer(ib),
			start = 0, num = num_indices,
		} or nil
	}

	return {handle = {
		sceneidx = 1,
		scenes = {
			-- scene 1
			{
				-- node 1
				{
					group,
				}
			}
		}
	}}
end

function util.create_grid_entity(world, name, w, h, unit, view_tag)
    local geopkg = import_package "ant.geometry"
    local geolib = geopkg.geometry

	local gridid = world:create_entity {
		transform = mu.identity_transform(),
        mesh = {},
        material = util.assign_material(fs.path "/pkg/ant.resources" / "materials" / "line.material"),
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

	local num_vertices = #vb
	local num_indices = #ib

	grid.mesh.assetinfo = util.create_simple_mesh( "p3|c40niu", gvb, num_vertices, ib, num_indices)
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
			ref_path = fs.path "/pkg/ant.resources/depiction/cube.mesh"
		},
		material = {
			content = {
				{
					ref_path = fs.path "/pkg/ant.resources/depiction/shadow/mesh_receive_shadow.material",
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

local function quad_mesh(vb)	
	return util.create_simple_mesh("p3|t2", vb, 4)
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

function util.create_quad_entity(world, rect, materialpath, properties, name, view_tag)
	view_tag = view_tag or "main_view"
	local eid = world:create_entity {
		transform = mu.identity_transform(),
		mesh = {},
		material = util.assign_material(materialpath, properties),
		can_render = true,
		[view_tag] = true,
		name = name or "quad",
	}

	local e = world[eid]
	e.mesh.assetinfo = util.quad_mesh(rect)
	return eid
end

function util.create_shadow_quad_entity(world, rect, name)
	return util.create_quad_entity(world, rect, 
		fs.path "/pkg/ant.resources/depiction/shadowmap_quad.material", nil, name)
end

function util.create_texture_quad_entity(world, texture_tbl, view_tag, name)
    local quadid = world:create_entity{
        transform = mu.identity_transform(),
        can_render = true,
        mesh = {},
        material = util.assign_material(
			fs.path "/pkg/ant.resources/materials/texture.material", 
			{textures = texture_tbl,}),
		name = name,
		[view_tag] = true,
    }
    local quad = world[quadid]
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

return util