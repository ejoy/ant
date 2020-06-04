local util = {}
util.__index = util

local declmgr 	= require "vertexdecl_mgr"

local hwi		= require "hardware_interface"

local assetmgr = import_package "ant.asset"

local mathpkg 	= import_package "ant.math"
local mu = mathpkg.util
local math3d = require "math3d"

local geopkg 	= import_package "ant.geometry"
local geodrawer	= geopkg.drawer

local function create_vb_buffer(flag, vb)
	return ("<"..flag:gsub("d", "I4"):rep(#vb/#flag)):pack(table.unpack(vb))
end

local function create_ib_buffer(ib)
	return ("<"..("I4"):rep(#ib)):pack(table.unpack(ib))
end

local function create_mesh(filename, vb_lst, ib)
	local mesh = {
		filename = filename,
		vb = {
			start = 0,
			values = {
			}
		}
	}
	local num = 0
	for i = 1, #vb_lst, 2 do
		local layout, vb = vb_lst[i], vb_lst[i+1]
		local correct_layout = declmgr.correct_layout(layout)
		local flag = declmgr.vertex_desc_str(correct_layout)
		local vb_value = create_vb_buffer(flag, vb)
		mesh.vb.values[#mesh.vb.values+1] = {
			declname = correct_layout,
			start = 1,
			num = #vb_value,
			value = vb_value,
		}
		num = num + #vb
	end
	mesh.vb.num = num
	if ib then
		local ib_value = ib and create_ib_buffer(ib)
		mesh.ib = {
			start = 0, num = #ib,
			value = {
				flag = "d",
				start = 1,
				num = #ib_value,
				value = ib_value,
			}
		}
	end
	return mesh
end

function util.create_mesh(filename, vb, ib)
	return create_mesh(filename, vb, ib)
end

function util.create_dynamic_mesh(filename, layout, num_vertices, num_indices)
	local decl = declmgr.get(layout)
	local vb_size = num_vertices * decl.stride

	assert(num_vertices <= 65535)
	local ib_size = num_indices * 2
	return {
		filename = filename,
		vb = {
			start = 0,
			num = num_vertices,
			values = {
				{
					declname = layout,
					dynamic = vb_size,
				}
			},
		},
		ib = num_indices and {
			start = 0,
			num = num_indices,
			value = {
				dynamic = ib_size,
			}
		}
	}
end

function util.create_submesh_item(material_refs)
	return {material_refs=material_refs, visible=true}
end

function util.is_entity_visible(e)
	return e.can_render
end

function util.create_grid_entity(world, name, w, h, unit)
	local geopkg = import_package "ant.geometry"
    local geolib = geopkg.geometry
	w = w or 64
	h = h or 64
	unit = unit or 1
	local vb, ib = geolib.grid(w, h, unit)
	local gvb = {}
	for _, v in ipairs(vb) do
		for _, vv in ipairs(v) do
			gvb[#gvb+1] = vv
		end
	end
	local mesh = create_mesh(assetmgr.generate_resource_name("mesh", "grid.meshbin"), {"p3|c40niu", gvb}, ib)
	return util.create_simple_render_entity(world, nil, "/pkg/ant.resources/materials/line.material", name, mesh)
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

function util.create_transform(world, transform)
	local srt = transform and transform.srt or {}
	return world.component "transform" {
		srt = world.component "srt"(srt)
	}
end

local plane_mesh
local function get_plane_mesh()
	if plane_mesh == nil then
		local vb = {
			-0.5, 0, 0.5, 0, 1, 0, 1, 0, 0,
			0.5,  0, 0.5, 0, 1, 0, 1, 0, 0,
			-0.5, 0,-0.5, 0, 1, 0, 1, 0, 0,
			0.5,  0,-0.5, 0, 1, 0, 1, 0, 0,
		}
		plane_mesh = create_mesh("//res.mesh/plane.meshbin", {"p3|n3|T3", vb})
		plane_mesh.bounding = {
			aabb = math3d.ref(math3d.aabb({-0.5, 0, -0.5}, {0.5, 0, 0.5}))
		}
	end
	return plane_mesh
end

function util.create_plane_entity(world, trans, materialpath, color, name, info)
	local policy = {
		"ant.render|render",
		"ant.render|mesh",
		"ant.general|name",
	}

	local data = {
		transform = util.create_transform(world, trans),
		material = world.component "resource"(materialpath or "/pkg/ant.resources/materials/test/singlecolor_tri_strip.material"),
		can_render = true,
		name = name or "Plane",
		scene_entity = true,
		mesh = get_plane_mesh(),
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
	e.material.properties.u_color = world.component "vector"(color)
	return eid
end

function util.quad_mesh(filename, rect)
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
	return create_mesh(filename, {"p3|t2", {
		x, 		y, 		0, 	0, minv,	--bottom left
		x,		y + h, 	0, 	0, maxv,	--top left
		x + w, 	y, 		0, 	1, minv,	--bottom right
		x + w, 	y + h, 	0, 	1, maxv,	--top right
	}})
end

function util.create_simple_render_entity(world, transform, material, name, mesh)
	return world:create_entity {
		policy = {
			"ant.render|render",
			"ant.render|mesh",
			"ant.general|name",
		},
		data = {
			transform = util.create_transform(world, transform or {srt={}}),
			material = world.component "resource"(material),
			mesh = mesh,
			can_render = true,
			name = name or "frustum",
			scene_entity = true,
		}
	}
end

local fullquad_meshres
function util.fullquad_mesh()
	if fullquad_meshres == nil then
		fullquad_meshres = util.quad_mesh("//res.mesh/fullquad.meshbin")
	end
	return fullquad_meshres
end

function util.create_quad_entity(world, rect, material, name)
	local mesh = util.quad_mesh(assetmgr.generate_resource_name("mesh", "quad.meshbin"), rect)
	return util.create_simple_render_entity(world, {srt={}}, material, name, mesh)
end

function util.create_texture_quad_entity(world, texture_tbl, name)
	local vb = {
		-3,  3, 0, 0, 0,
		 3,  3, 0, 1, 0,
		-3, -3, 0, 0, 1,
		 3, -3, 0, 1, 1,
	}
	local mesh = create_mesh(assetmgr.generate_resource_name("mesh", "quad_scale3.meshbin"), {"p3|t2", vb})
	local eid = util.create_simple_render_entity(world, nil, "/pkg/ant.resources/materials/texture.material",  name, mesh)
	local e = world[eid]
	assetmgr.patch(e.material, {properties = texture_tbl})
	return eid
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

local frustum_ib = {
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

function util.create_frustum_entity(world, frustum_points, name, color)
	local vb = {}
	color = color or 0xff00000f
	for i=1, #frustum_points do
		local p = math3d.totable(frustum_points[i])
		table.move(p, 1, 3, #vb+1, vb)
		vb[#vb+1] = color
	end
	local resname = assetmgr.generate_resource_name("mesh", "frustum.meshbin")
	local mesh = create_mesh(resname, {"p3|c40niu", vb}, frustum_ib)
	return util.create_simple_render_entity(world, nil, "/pkg/ant.resources/materials/line.material", name, mesh)
end

local axis_ib = {
	0, 1,
	0, 2, 
	0, 3,
}
function util.create_axis_entity(world, transform, color, name)
	local axis_vb = {
		0, 0, 0, color or 0xff0000ff,
		1, 0, 0, color or 0xff0000ff,
		0, 0, 0, color or 0xff00ff00,
		0, 1, 0, color or 0xff00ff00,
		0, 0, 0, color or 0xffff0000,
		0, 0, 1, color or 0xffff0000,
	}
	local resname = assetmgr.generate_resource_name("mesh", "axis.meshbin")
	local mesh = create_mesh(resname, {"p3|c40niu", axis_vb}, axis_ib)
	return util.create_simple_render_entity(world, transform, "/pkg/ant.resources/materials/line.material", name, mesh)
end


local skybox_mesh
local function get_skybox_mesh()
	if skybox_mesh == nil then
		local desc = {vb={}, ib={}}
		geodrawer.draw_box({1, 1, 1}, nil, nil, desc)
		local gvb = {}
		for _, v in ipairs(desc.vb)do
			table.move(v, 1, 3, #gvb+1, gvb)
		end
		skybox_mesh = create_mesh("skybox.meshbin", {"p3", gvb}, desc.ib)
	end

	return skybox_mesh
end

function util.create_skybox(world, material)
    return world:create_entity {
		policy = {
			"ant.render|render",
			"ant.render|mesh",
			"ant.general|name",
		},
		data = {
			transform = world.component "transform" {srt=mu.srt()},
			material = world.component "resource"(material or "/pkg/ant.resources/materials/skybox.material"),
			can_render = true,
			scene_entity = true,
			name = "sky_box",
			mesh = get_skybox_mesh(),
		}
	}
end

function util.check_rendermesh_lod(meshscene, lod_scene)
	if meshscene.scenelods then
		if meshscene.scenelods[meshscene.scene] == nil then
			log.warn("not found scene from scenelods", meshscene.scene)
		end
	else
		if meshscene.scene ~= lod_scene then
			log.warn("default lod scene is not equal to lodidx")
		end
	end
end

function util.entity_bounding(entity)
	assert(false, "TODO")
	--if util.is_entity_visible(entity) then
	--	local meshscene = entity.render-mesh
	--	local etrans = entity.transform.srt
	--	local scene = meshscene.scenes[meshscene.scene]
	--	local aabb = math3d.aabb()
	--	for _, mn in pairs(scene)	do
	--		local localtrans = mn.transform
	--		for _, g in ipairs(mn) do
	--			local b = g.bounding
	--			if b then
	--				aabb = math3d.aabb_transform(localtrans, math3d.aabb_merge(aabb, b.aabb))
	--			end
	--		end
	--	end
	--	aabb = math3d.aabb_transform(etrans, aabb)
	--	return math3d.aabb_isvalid(aabb) and aabb or nil
	--end
end

function util.create_procedural_sky(world, settings)
	settings = settings or {}
	local function attached_light(eid)
		if eid then
			return world[eid].serialize
		end
	end
    return world:create_entity {
		policy = {
			"ant.render|render",
			"ant.sky|procedural_sky",
			"ant.general|name",
		},
		data = {
			transform = util.create_transform(world),
			material = world.component "resource" "/pkg/ant.resources/materials/sky/procedural/procedural_sky.material",
			procedural_sky = world.component "procedural_sky" {
				grid_width = 32,
				grid_height = 32,
				--attached_sun_light = attached_light(settings.attached_sun_light),
				which_hour 	= settings.whichhour or 12,	-- high noon
				turbidity 	= settings.turbidity or 2.15,
				month 		= settings.whichmonth or "June",
				latitude 	= settings.whichlatitude or math.rad(50),
			},
			can_render = true,
			scene_entity = true,
			name = "procedural sky",
		}
	}
end

local function sort_pairs(t)
    local s = {}
    for k in pairs(t) do
        s[#s+1] = k
    end

    table.sort(s)

    local n = 1
    return function ()
        local k = s[n]
        if k == nil then
            return
        end
        n = n + 1
        return k, t[k]
    end
end

return util