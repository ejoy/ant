local util = {}
util.__index = util

local fs 		= require "filesystem"
local bgfx 		= require "bgfx"
local declmgr 	= require "vertexdecl_mgr"

local animodule = require "hierarchy.animation"
local hwi		= require "hardware_interface"

local assetmgr = import_package "ant.asset"

local mathpkg 	= import_package "ant.math"
local mu = mathpkg.util
local mc = mathpkg.constant
local math3d = require "math3d"

local geopkg 	= import_package "ant.geometry"
local geodrawer	= geopkg.drawer

function util.create_submesh_item(material_refs)
	return {material_refs=material_refs, visible=true}
end

function util.change_textures(content, texture_tbl)
	if content.properties == nil then
		content.properties = {}
	end
	content.properties.textures = texture_tbl
end

function util.is_entity_visible(e)
	return e.can_render
end

function util.assign_group_as_mesh(group)
	return {
		default_scene = "sceneroot",
		scenes = {
			sceneroot = {
				meshnode = {
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
				{handle = bgfx.create_vertex_buffer(vb, declmgr.get(vertex_desc).handle)},
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
	local vb_size = num_vertices * decl.stride

	assert(num_vertices <= 65535)
	local ib_size = num_indices * 2
	return util.assign_group_as_mesh {
		vb = {
			handles = {
				{
					handle = bgfx.create_dynamic_vertex_buffer(vb_size, decl.handle, "a"),
					updatedata = animodule.new_aligned_memory(vb_size),
				}
			},
			start = 0,
			num = num_vertices,
		},
		ib = num_indices and {
			handle = bgfx.create_dynamic_index_buffer(ib_size, "a"),
			updatedata = animodule.new_aligned_memory(ib_size),
			start = 0,
			num = num_indices,
		}
	}
end

function util.create_grid_entity(world, name, w, h, unit, transform)
    local geopkg = import_package "ant.geometry"
    local geolib = geopkg.geometry

	local gridid = world:create_entity {
		policy = {
			"ant.render|render",
			"ant.general|name",
		},
		data = {
			transform = transform,
			rendermesh = {},
			material = "/pkg/ant.resources/materials/line.material",
			name = name,
			can_render = true,
			scene_entity = true,
		}
    }
    local grid = world[gridid]
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

	grid.rendermesh = assetmgr.load("//res.mesh/grid.rendermesh", util.create_simple_mesh( "p3|c40niu", gvb, num_vertices, ib, num_indices))
    return gridid
end

function util.quad_vertices(rect)
	rect = rect or {x=0, y=0, w=1, h=1}
	return {
		rect.x, 		 rect.y, 		
		rect.x, 		 rect.y + rect.h, 
		rect.x + rect.w, rect.y, 		
		rect.x + rect.w, rect.y + rect.h, 
	}
end

function util.create_plane_entity(world, trans, materialpath, color, name, info)
	local policy = {
		"ant.render|render",
		"ant.general|name",
	}

	local material = ([[
---
%s
---
op: replace
path: /properties/uniforms/u_color
value:
  type: color
  value:
    {%f,%f,%f,%f}
]]):format(
	materialpath or "/pkg/ant.resources/materials/test/singlecolor_tri_strip.material",
	color[1], color[2], color[3], color[4]
)
	local data = {
		transform = trans,
		rendermesh = {},
		material = material,
		can_render = true,
		name = name or "Plane",
		scene_entity = true,
	}

	if info then
		for policy_name, dd in pairs(info) do
			policy[#policy+1] = policy_name
			for k, d in pairs(dd) do
				data[k] = d
			end
		end
	end

	local eid = world:create_entity{
		policy = policy,
		data = data,
	}
	
	local e = world[eid]
	local vb = {
		"fffffffff",
		-0.5, 0, 0.5, 0, 1, 0, 1, 0, 0,
		0.5,  0, 0.5, 0, 1, 0, 1, 0, 0,
		-0.5, 0,-0.5, 0, 1, 0, 1, 0, 0,
		0.5,  0,-0.5, 0, 1, 0, 1, 0, 0,
	}
	local meshscene = assetmgr.load("//res.mesh/plane.rendermesh", util.create_simple_mesh("p3|n3|T3", vb, 4))
	local selectscene = meshscene.scenes[meshscene.default_scene]
	local _, meshnode = next(selectscene)
	meshnode.bounding = {
		aabb = math3d.ref(math3d.aabb({-0.5, 0, -0.5}, {0.5, 0, 0.5}))
	}

	e.rendermesh = meshscene
	return eid
end

local function quad_mesh(vb)
	return util.create_simple_mesh("p3|t2", vb, 4)
end

function util.quad_mesh(rect)
	local origin_bottomleft = hwi.get_caps().originBottomLeft
	local minv, maxv
	if origin_bottomleft then
		minv, maxv = 0, 1
	else
		minv, maxv = 1, 0
	end
	local x, y, w, h
	if rect then
		x, y = rect.x or 0, rect.y or 0
		w, h = rect.w, rect.h
	else
		x, y = -1, -1
		w, h = 2, 2
	end

	return quad_mesh{
		"fffff",
		x, 		y, 		0, 	0, minv,	--bottom left
		x,		y + h, 	0, 	0, maxv,	--top left
		x + w, 	y, 		0, 	1, minv,	--bottom right
		x + w, 	y + h, 	0, 	1, maxv,	--top right
	}
end

local function create_simple_render_entity(world, transform, material, name, tag)
	local dataset = {
		transform = transform,
		rendermesh = {},
		material = material,
		can_render = true,
		name = name or "frustum",
		scene_entity = true,
	}
	if tag then
		dataset[tag] = true
	end
	return world:create_entity {
		policy = {
			"ant.render|render",
			"ant.general|name",
		},
		data = dataset,
	}
end

local quadmesh_index
local function generate_quad_mesh_name()
	local name = "//res.mesh/quad.rendermesh"
	if quadmesh_index == nil then
		quadmesh_index = 1
	else
		name = name .. quadmesh_index
		quadmesh_index = quadmesh_index + 1
	end

	return name
end
function util.create_quad_entity(world, rect, material, name, tag)
	local eid = create_simple_render_entity(world, {srt={}}, material, name, tag)
	world[eid].rendermesh = assetmgr.load(generate_quad_mesh_name(), util.quad_mesh(rect))
	return eid
end

function util.create_texture_quad_entity(world, texture_tbl, name)
	local quadid = create_simple_render_entity( world, nil, {
		ref_path = fs.path "/pkg/ant.resources/materials/texture.material",
		properties = texture_tbl,
	}, name)

    local quad = world[quadid]
	local vb = {
		"fffff",
		-3,  3, 0, 0, 0,
		 3,  3, 0, 1, 0,
		-3, -3, 0, 0, 1,
		 3, -3, 0, 1, 1,
	}
	
	quad.rendermesh = assetmgr.load("//res.mesh/quad_scale3.rendermesh", quad_mesh(vb))
    return quadid
end

function util.get_mainqueue_transform_boundings(world, transformed_boundings)
	local mq = world:singleton_entity "main_queue"
	local filter = mq.primitive_filter
	for _, fname in ipairs{"opaticy", "translucent"} do
		local result = filter.result[fname]
		local visibleset = result.visible_set.n and result.visible_set or result
		local num = visibleset.n
		if num > 0 then
			for i=1, num do
				local prim = visibleset[i]
				transformed_boundings[#transformed_boundings+1] = prim.aabb
			end
		end
	end
end

function util.create_frustum_entity(world, frustum_points, name, transform, color, tag)
	local eid = create_simple_render_entity(world, transform, "/pkg/ant.resources/materials/line.material", name, tag)

	local e = world[eid]
	local vb = {"fffd",}
	color = color or 0xff00000f
	for i=1, #frustum_points do
		local p = math3d.totable(frustum_points[i])
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
	
	e.rendermesh = assetmgr.load("//res.mesh/frustum.rendermesh", util.create_simple_mesh("p3|c40niu", vb, 8, ib, #ib))
	return eid
end

function util.create_axis_entity(world, transform, color, name, tag)
	local eid = create_simple_render_entity(world, transform, "/pkg/ant.resources/materials/line.material", name, tag)

	local vb = {
		"fffd",
		0, 0, 0, color or 0xffffffff,
		1, 0, 0, color or 0xff0000ff,
		0, 1, 0, color or 0xff00ff00,
		0, 0, 1, color or 0xffff0000,
	}
	local ib = {
		0, 1,
		0, 2, 
		0, 3,
	}
	world[eid].rendermesh = assetmgr.load("//res.mesh/axis.rendermesh", util.create_simple_mesh("p3|c40niu", vb, 4, ib, #ib))
	return eid
end

function util.create_skybox(world, material)
    local eid = world:create_entity {
		policy = {
			"ant.render|render",
			"ant.general|name"
		},
		data = {
			transform = {srt=mu.srt()},
			rendermesh = {},
			material = material or "/pkg/ant.resources/materials/skybox.material",
			can_render = true,
			scene_entity = true,
			name = "sky_box",
		}
    }
    local e = world[eid]

    local desc = {vb={}, ib={}}
    geodrawer.draw_box({1, 1, 1}, nil, nil, desc)
    local gvb = {"fff",}
    for _, v in ipairs(desc.vb)do
        table.move(v, 1, 3, #gvb+1, gvb)
    end
    e.rendermesh = assetmgr.load("//res.mesh/skybox.rendermesh", util.create_simple_mesh("p3", gvb, 8, desc.ib, #desc.ib))
    return eid
end

function util.check_rendermesh_lod(meshscene, lod_scene)
	if meshscene.scenelods then
		if meshscene.scenelods[meshscene.default_scene] == nil then
			log.warn("not found scene from scenelods", meshscene.default_scene)
		end
	else
		if meshscene.default_scene ~= lod_scene then
			log.warn("default lod scene is not equal to lodidx")
		end
	end
end

function util.entity_bounding(entity)
	if util.is_entity_visible(entity) then
		local meshscene = entity.rendermesh
		local etrans = entity.transform.srt
		local scene = meshscene.scenes[meshscene.default_scene]
		local aabb = math3d.aabb()
		for _, mn in pairs(scene)	do
			local localtrans = mn.transform
			for _, g in ipairs(mn) do
				local b = g.bounding
				if b then
					aabb = math3d.aabb_transform(localtrans, math3d.aabb_merge(aabb, b.aabb))
				end
			end
		end

		aabb = math3d.aabb_transform(etrans, aabb)
		return math3d.aabb_isvalid(aabb) and aabb or nil
	end
end


return util