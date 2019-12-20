local util = {}
util.__index = util

local fs 		= require "filesystem"
local bgfx 		= require "bgfx"
local declmgr 	= require "vertexdecl_mgr"
local mathbaselib = require "math3d.baselib"
local animodule = require "hierarchy.animation"
local hwi		= require "hardware_interface"

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
	return {ref_path = filepath, properties = properties, asyn_load=asyn_load}
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

function util.create_grid_entity(world, name, w, h, unit, transform)
    local geopkg = import_package "ant.geometry"
    local geolib = geopkg.geometry

	local gridid = world:create_entity {
		policy = {
			"render",
			"name",
		},
		data = {
			transform = transform or mu.identity_transform(),
			rendermesh = {},
			material = util.assign_material(fs.path "/pkg/ant.resources" / "depiction" / "materials" / "line.material"),
			name = name,
			can_render = true,
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

	grid.rendermesh.reskey = assetmgr.register_resource(fs.path "//meshres/grid.mesh", util.create_simple_mesh( "p3|c40niu", gvb, num_vertices, ib, num_indices))
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

function util.create_plane_entity(world, size, pos, materialpath, color, name, needcollider)
	local policy = {
		"render",
		"name",
	}

	local scale = size or {1, 1, 1, 0}

	local data = {
		transform = {
			s = scale,
			r = {0, 0, 0, 0},
			t = pos or {0, 0, 0, 1}
		},
		rendermesh = {},
		material = util.assign_material(
				materialpath or fs.path "/pkg/ant.resources/depiction/materials/test/singlecolor_tri_strip.material",
				{uniforms = {u_color = {type="color", name="color", value=color}},}),
		can_render = true,
		name = name or "Plane",
	}
	if needcollider then
		policy[#policy+1] = "box"

		data["collider_tag"] = "box_collider"
		data["box_collider"] = {
			collider = {
				center = {0, 0, 0},
			},
			shape = {
				size = scale,
			}
		}
	end

	local eid = world:create_entity {
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
	e.rendermesh.reskey = assetmgr.register_resource(fs.path "//meshres/plane.mesh", util.create_simple_mesh("p3|n3|T3", vb, 4))
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
	return quad_mesh{
		"fffff",
		rect.x, 		 rect.y, 			0, 	0, minv,	--bottom left
		rect.x, 		 rect.y + rect.h, 	0, 	0, maxv,	--top left
		rect.x + rect.w, rect.y, 			0, 	1, minv,	--bottom right
		rect.x + rect.w, rect.y + rect.h, 	0, 	1, maxv,	--top right
	}
end

function util.create_quad_entity(world, rect, materialpath, properties, name)
	local eid = world:create_entity {
		policy = {
			"name",
			"render",
		},
		data = {
			transform = mu.identity_transform(),
			rendermesh = {},
			material = util.assign_material(materialpath, properties),
			can_render = true,
			name = name or "quad",
		}
	}

	local e = world[eid]
	e.rendermesh.reskey = assetmgr.register_resource(fs.path "//meshres/quad.mesh", util.quad_mesh(rect))
	return eid
end

function util.create_shadow_quad_entity(world, rect, name)
	return util.create_quad_entity(world, rect, 
		fs.path "/pkg/ant.resources/depiction/materials/shadow/shadowmap_quad.material", name)
end

function util.create_texture_quad_entity(world, texture_tbl, name)
    local quadid = world:create_entity{
		policy = {
			"render",
			"name",
		},
		data = {
			transform = mu.identity_transform(),
			can_render = true,
			rendermesh = {},
			material = util.assign_material(
				fs.path "/pkg/ant.resources/materials/texture.material", 
				{textures = texture_tbl,}),
			name = name,			
		}

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
		policy = {
			"render",
			"name",
		},
		data = {
			transform = transform or mu.srt(),
			rendermesh = {},
			material = util.assign_material(fs.path "/pkg/ant.resources/depiction/materials/line.material"),
			can_render = true,
			name = name or "frustum"
		}

	}

	local e = world[eid]
	local m = e.rendermesh
	local vb = {"fffd",}
	color = color or 0xff00000f
	for i=1, #points do
		local p = points[i]
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
	
	m.reskey = assetmgr.register_resource(fs.path "//meshres/frustum.mesh", util.create_simple_mesh("p3|c40niu", vb, 8, ib, #ib))
	return eid
end

function util.create_axis_entity(world, transform, color, name)
	local eid = world:create_entity {
		policy = {
			"render",
			"name",
		},
		data = {
			transform = transform or mu.srt(),
			rendermesh = {},
			material = {
				{ref_path = fs.path "/pkg/ant.resources/depiction/materials/line.material"},
			},
			name = name or "axis",
			can_render = true,
		}
	}

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
	world[eid].rendermesh.reskey = assetmgr.register_resource(fs.path "//meshres/axis.mesh", util.create_simple_mesh("p3|c40niu", vb, 4, ib, #ib))
	return eid
end

function util.create_skybox(world, material)
    local eid = world:create_entity {
		policy = {
			"render",
			"name"
		},
		data = {
			transform = mu.srt(),
			rendermesh = {},
			material = material or util.assign_material(fs.path "/pkg/ant.resources/depiction/materials/skybox.material"),
			can_render = true,
			name = "sky_box",
		}
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

function util.create_mesh_buffers(meshres)
	local meshscene = {
		sceneidx = meshres.sceneidx,
		scenelods = meshres.scenelods,
	}
	local new_scenes = {}
	for _, scene in ipairs(meshres.scenes) do
		local new_scene = {}
		for _, meshnode in ipairs(scene) do
			local new_meshnode = {
				bounding = meshnode.bounding,
				transform = meshnode.transform,
				meshname = meshnode.meshname,
			}
			for _, group in ipairs(meshnode) do
				local vb = group.vb
				local handles = {}
				for _, value in ipairs(vb.values) do
					local create_vb = value.type == "dynamic" and bgfx.create_dynamic_vertex_buffer or bgfx.create_vertex_buffer
					local start_bytes = value.start
					local end_bytes = start_bytes + value.num - 1

					handles[#handles+1] = {
						handle = create_vb({"!", value.value, start_bytes, end_bytes},
											declmgr.get(value.declname).handle),
						updatedata = value.type == "dynamic" and animodule.new_aligned_memory(value.num, 4) or nil,
					}
				end
				local new_meshgroup = {
					bounding = group.bounding,
					material = group.material,
					mode = group.mode,
					vb = {
						start = vb.start,
						num = vb.num,
						handles = handles,
					}
				}
	
				local ib = group.ib
				if ib then
					local v = ib.value
					local create_ib = v.type == "dynamic" and bgfx.create_dynamic_index_buffer or bgfx.create_index_buffer
					local startbytes = v.start
					local endbytes = startbytes+v.num-1
					new_meshgroup.ib = {
						start = ib.start,
						num = ib.num,
						handle = create_ib({v.value, startbytes, endbytes}, v.flag),
						updatedata = v.type == "dynamic" and animodule.new_aligned_memory(v.num) or nil
					}
				end
	
				new_meshnode[#new_meshnode+1] = new_meshgroup
			end

			local ibm = meshnode.inverse_bind_matries
			if ibm then
				new_meshnode.inverse_bind_pose 	= animodule.new_bind_pose(ibm.num, ibm.value)
				new_meshnode.joint_remap 		= animodule.new_joint_remap(ibm.joints)
			end
			new_scene[#new_scene+1] = new_meshnode
		end
		new_scenes[#new_scenes+1] = new_scene
	end

	meshscene.scenes = new_scenes
		
	return meshscene
end

function util.create_mesh(rendermesh, mesh)
	local res = assetmgr.get_resource(mesh.ref_path)
	check_rendermesh_lod(res)
	
	local ref_path = mesh.ref_path
	local reskey = fs.path ("//meshres/" .. ref_path:string())
	local meshscene = assetmgr.get_resource(reskey)
	if meshscene == nil then
		local meshscene = util.create_mesh_buffers(res)
		assetmgr.register_resource(reskey, meshscene)
		-- just for debug
		mesh.debug_meshscene_DOTNOT_DIRECTLY_USED 		= {meshscene, res}
		rendermesh.debug_meshscene_DOTNOT_DIRECTLY_USED = mesh.debug_meshscene_DOTNOT_DIRECTLY_USED
	end

	rendermesh.reskey = reskey
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