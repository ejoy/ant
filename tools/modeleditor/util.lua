local util = {}; util.__index = util

local geo = require "editor.ecs.render.geometry"
local computil = require "render.components.util"

local loaderutil = require "modelloader.util"
local ms = require "math.stack"
local mu = require "math.util"
local bgfx = require "bgfx"

local bu = require "bullet.lua.util"

function util.create_aabb_descs(mesh, materialfile)
	local descs = {}
	local _, ib = geo.box_from_aabb(nil, true, true)
	for _, g in ipairs(mesh.assetinfo.handle.groups) do
		local bounding = g.bounding
		local aabb = assert(bounding.aabb)
		
		local vb = geo.box_from_aabb(aabb)
		table.insert(descs, {
			vb = vb,
			ib = ib,
			material = materialfile,
		})
	end
	return descs
end

local sample_obj_user_idx = 1

local function gen_mesh_assetinfo(skinning_mesh_comp)	
	local skinning_mesh = skinning_mesh_comp.assetinfo.handle

	local decls = {}
	local vb_handles = {}
	local vb_data = {"!", "", 1}
	for _, type in ipairs {"dynamic", "static"} do
		local layout = skinning_mesh:layout(type)
		local decl = loaderutil.create_decl(layout)
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

local function add_aabb_widget(world, eid)
	world:add_component(eid, "widget")
	local e = world[eid]
	local aabb_material = "line.material"
	local descs = util.create_aabb_descs(e.mesh, aabb_material)
	if #descs == 0 then
		return 
	end

	local ibhandle = bgfx.create_index_buffer(descs[1].ib)
	local decl = bgfx.vertex_decl {
		{ "POSITION", 3, "FLOAT" },
		{ "COLOR0", 4, "UINT8", true },
	}

	local function create_mesh_groups(descs, color)
		local groups = {}
		for _, desc in ipairs(descs) do
			local vb = {"fffd",}
			for _, v in ipairs(desc.vb) do
				for _, vv in ipairs(v) do
					table.insert(vb, vv)
				end
				table.insert(vb, color)
			end

			table.insert(groups, {
					vb = {handles = {	bgfx.create_vertex_buffer(vb, decl)	}},
					ib = {handle = ibhandle},
				})
		end

		return groups
	end

	local widget = e.widget
	widget.mesh = {
		descs = descs,
		assetinfo = {
			handle = {
				groups = create_mesh_groups(descs, 0xffff0000),
			}
		}
	}

	widget.material = {
		content = {}
	}
	computil.load_material(widget.material, {aabb_material})

	widget.srt = {}--{s=e.scale, r=nil, t=e.position}
end

local smaplemaerial = "skin_model_sample.material"

function util.create_sample_entity(world, skepath, anipath, skinning_meshpath)
	local eid = world:new_entity("position", "scale", "rotation",	
	"rigid_body",		-- physic relate
	"mesh", "material",
	"sampleobj", 
	"name", "can_render")

	local e = world[eid]
	e.name = "animation_test"

	mu.identify_transform(e)

	if skepath and skepath ~= "" then
		world:add_component(eid, "skeleton")
		computil.load_skeleton(e.skeleton, skepath)
	end

	if anipath and anipath ~= "" then
		world:add_component(eid, "animation")
		computil.load_animation(e.animation, e.skeleton, anipath)
	end

	local skinning_mesh
	if skinning_meshpath and skinning_meshpath ~= "" then
		if e.skeleton and e.animation then
			world:add_component(eid, "skinning_mesh")
			skinning_mesh = e.skinning_mesh
		else
			skinning_mesh = {}
		end

		computil.load_skinning_mesh(skinning_mesh, skinning_meshpath)			
	end
	
	e.mesh.assetinfo = gen_mesh_assetinfo(skinning_mesh)

	local function init_physic_obj()
		local rigid_body = e.rigid_body
		
		local aabb = e.mesh.assetinfo.handle.groups[1].bounding.aabb
		local len = math.sqrt(ms(aabb.max, aabb.min, "-1.T")[1])

		local phy_world = world.args.physic_world

		local shape = {type= "capsule", radius=0.1 * len, height=0.8 * len, axis=2}
		shape.handle = bu.create_shape(phy_world, shape.type, shape)		
		table.insert(rigid_body.shapes, shape)
		
		local colobj = assert(rigid_body).obj
		colobj.handle = phy_world:new_obj(shape.handle, sample_obj_user_idx, {0, 0, 0}, {0, 0, 0, 1})
		colobj.useridx = sample_obj_user_idx
	end

	init_physic_obj()

	computil.load_material(e.material,{smaplemaerial})

	add_aabb_widget(world, eid)
	return eid
end

return util