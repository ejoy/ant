local util = {}
util.__index = util

local fs 		= require "filesystem"
local bgfx 		= require "bgfx"
local declmgr 	= require "vertexdecl_mgr"
local mathbaselib = require "math3d.baselib"

local assetpkg 	= import_package "ant.asset"
local assetmgr 	= assetpkg.mgr
local assetutil	= assetpkg.util

local mathpkg 	= import_package "ant.math"
local mu = mathpkg.util
local ms = mathpkg.stack

local geopkg 	= import_package "ant.geometry"
local geodrawer	= geopkg.drawer

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

function util.add_material(material, filename)
	local item = {
		ref_path = filename,
	}
	util.create_material(item)
    material[#material + 1] = item
end

function util.create_material(material)
	assetmgr.load(material.ref_path)
	assetutil.load_material_properties(material.properties)
end

function util.remove_material(material)
	assetmgr.unload(material.ref_path)
	material.ref_path = nil

	assetutil.unload_material_properties(material.properties)
	material.properties = nil
end

function util.assign_material(filepath, properties, asyn_load)
	return {
		{ref_path = filepath, properties = properties, asyn_load=asyn_load}
	}
end

function util.create_submesh_item(material_refs)
	return {material_refs=material_refs, visible=true}
end

function util.change_textures(content, texture_tbl)
	if content.properties then
		if content.properties.textures then
			assetutil.unload_material_textures(content.properties)
		end
	else
		content.properties = {}
	end
	content.properties.textures = texture_tbl
	assetutil.load_material_textures(content.properties)
end

function util.is_entity_visible(entity)
    local can_render = entity.can_render
	if can_render then
		local al = entity.asyn_load
		local rm = entity.rendermesh
		if al then
			return al == "loaded" and rm.handle ~= nil
		end
        return rm.handle ~= nil
    end

    return false
end

function util.assign_group_as_mesh(group)
	return {
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
	}
end

function util.create_simple_mesh(vertex_desc, vb, num_vertices, ib, num_indices)
	return util.assign_group_as_mesh {
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
end

function util.create_simple_dynamic_mesh(vertex_desc, num_vertices, num_indices)
	local decl = declmgr.get(vertex_desc)
	return util.assign_group_as_mesh {
		vb = {
			handles = {
				bgfx.create_dynamic_vertex_buffer(num_vertices * decl.stride, decl.handle, "a"),
			},
			start = 0,
			num = num_vertices,
		},
		ib = num_indices and {
			handle = bgfx.create_dynamic_index_buffer(num_indices * 2, "a"),
			start = 0,
			num = num_indices,
		}
	}
end

function util.create_grid_entity(world, name, w, h, unit, view_tag)
    local geopkg = import_package "ant.geometry"
    local geolib = geopkg.geometry

	local gridid = world:create_entity {
		transform = mu.identity_transform(),
        rendermesh = {},
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

	grid.rendermesh.reskey = assetmgr.register_resource(fs.path "//meshres/grid.mesh", util.create_simple_mesh( "p3|c40niu", gvb, num_vertices, ib, num_indices))
    return gridid
end

function util.create_plane_entity(world, color, size, pos, name)
	return world:create_entity {
		transform = {
			s = size or {0.08, 0.005, 0.08},
			r = {0, 0, 0, 0},
			t = pos or {0, 0, 0, 1}
		},
		rendermesh = {},
		mesh = {ref_path = fs.path "/pkg/ant.resources/depiction/cube.mesh"},
		material = util.assign_material(
				fs.path "/pkg/ant.resources/depiction/shadow/mesh_receive_shadow.material",
				{uniforms = {u_color = {type="color", name="color", value=color}},}),
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
		rendermesh = {},
		material = util.assign_material(materialpath, properties),
		can_render = true,
		[view_tag] = true,
		name = name or "quad",
	}

	local e = world[eid]
	e.rendermesh.reskey = assetmgr.register_resource(fs.path "//meshres/quad.mesh", util.quad_mesh(rect))
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
        rendermesh = {},
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
	
	quad.rendermesh.reskey = assetmgr.register_resource(fs.path "//meshres/quad_scale3.mesh", quad_mesh(vb))
    return quadid
end

function util.calc_transform_boundings(world, transformed_boundings)
	for _, eid in world:each "can_render" do
		local e = world[eid]

		if e.mesh_bounding_drawer_tag == nil and e.main_view then
			local rm = e.rendermesh
			local meshscene = rm.handle

			local worldmat = ms:srtmat(e.transform)

			for _, scene in ipairs(meshscene.scenes) do
				for _, mn in ipairs(scene)	do
					local trans = worldmat
					if mn.transform then
						trans = ms(trans, mn.transform, "*P")
					end

					for _, g in ipairs(mn) do
						local b = g.bounding
						if b then
							local tb = mathbaselib.new_bounding(ms)
							tb:reset(b, trans)
							transformed_boundings[#transformed_boundings+1] = tb
						end
					end
				end
			end
		end
	end
end

function util.create_frustum_entity(world, frustum, name, transform, color)
	local points = frustum:points()
	local eid = world:create_entity {
		transform = transform or mu.srt(),
		rendermesh = {},
		material = util.assign_material(fs.path "/pkg/ant.resources/depiction/materials/line.material"),
		can_render = true,
		main_view = true,
		name = name or "frustum"
	}

	local e = world[eid]
	local m = e.rendermesh
	local vb = {"fffd",}
	local cornernames = {
		"ltn", "lbn", "rtn", "rbn",
		"ltf", "lbf", "rtf", "rbf",
	}

	color = color or 0xff00000f
	for _, n in ipairs(cornernames) do
		local p = points[n]
		table.move(p, 1, 3, #vb+1, vb)
		vb[#vb+1] = color
	end

	local ib = {
		-- front
		0, 1, 2, 3,
		0, 2, 1, 3,

		-- back
		4, 5, 6, 7,
		4, 6, 5, 7,

		-- left
		0, 4, 1, 5,
		-- right
		2, 6, 3, 7,
	}
	
	
	m.handle = util.create_simple_mesh("p3|c40niu", vb, 8, ib, #ib)
	return eid
end

function util.create_skybox(world, material)
    local eid = world:create_entity {
        transform = mu.srt(),
        rendermesh = {},
        material = material or util.assign_material(fs.path "/pkg/ant.resources/depiction/materials/skybox.material"),
        can_render = true,
        main_view = true,
        name = "sky_box",
    }
    local e = world[eid]
    local rm = e.rendermesh

    local desc = {vb={}, ib={}}
    geodrawer.draw_box({1, 1, 1}, nil, nil, desc)
    local gvb = {"fff",}
    for _, v in ipairs(desc.vb)do
        table.move(v, 1, 3, #gvb+1, gvb)
    end
    rm.handle = util.create_simple_mesh("p3", gvb, 8, desc.ib, #desc.ib)
    return eid
end

local function check_rendermesh_lod(meshscene, lodidx)
	if meshscene.scenelods then
		assert(1 <= meshscene.sceneidx and meshscene.sceneidx <= #meshscene.scenelods)
		if lodidx < 1 or lodidx > #meshscene.scenelods then
			log.warn("invalid lod:", lodidx, "max lod:", meshscene.scenelods)
		end
	else
		if meshscene.sceneidx ~= lodidx then
			log.warn("default lod scene is not equal to lodidx")
		end
	end
end

function util.create_mesh(rendermesh, mesh)
	local res = assetmgr.load(mesh.ref_path)
	check_rendermesh_lod(res)
	rendermesh.reskey = mesh.ref_path
	-- just for debug
	mesh.debug_rendermesh = rendermesh
end

function util.check_mesh_valid(rendermesh, mesh)
	if rendermesh.reskey then
		return mesh.debug_rendermesh == rendermesh
	end
	return rendermesh.handle ~= nil
end

function util.remove_mesh(rendermesh, mesh)
	if util.check_mesh_valid(rendermesh, mesh) then
		rendermesh.reskey = nil
		assetmgr.unload(mesh.ref_path)
		mesh.ref_path = nil
		mesh.debug_rendermesh = nil
	end
end

function util.scene_index(lodidx, meshscene)
	local lodlevel = lodidx or meshscene.sceneidx
	return meshscene.scenelods and (meshscene.scenelods[lodlevel]) or meshscene.sceneidx
end

function util.entity_bounding(entity)
	if util.is_entity_visible(entity) then
		local rm = entity.rendermesh
		local meshscene = rm.handle
		local sceneidx = util.scene_index(rm.lodidx, meshscene)

		local worldmat = ms:srtmat(entity.transform)

		local scene = meshscene.scenes[sceneidx]
		local entitybounding = mathbaselib.new_bounding(ms)
		for _, mn in ipairs(scene)	do
			local trans = worldmat
			if mn.transform then
				trans = ms(trans, mn.transform, "*P")
			end

			for _, g in ipairs(mn) do
				local b = g.bounding
				if b then
					local tb = mathbaselib.new_bounding(ms)
					tb:reset(b, trans)
					entitybounding:merge(tb)
				end
			end
		end
		
		return entitybounding:isvalid() and entitybounding or nil
	end
end


return util