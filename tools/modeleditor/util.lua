local util = {}; util.__index = util

local geometry = import_package "ant.geometry"
local geo = geometry.geometry

local fs = require "filesystem"
local bgfx = require "bgfx"

function util.create_aabb_mesh_info(mesh)
	local descs = {}
	local _, ib = geo.box_from_aabb(nil, true, true)
	for _, g in ipairs(mesh.assetinfo.handle.groups) do
		local bounding = g.bounding
		local aabb = assert(bounding.aabb)
		
		local vb = geo.box_from_aabb(aabb)
		table.insert(descs, {
			vb = vb,
			ib = ib,			
		})
	end
	return descs
end

function util.create_sample_entity(world, skepath, anipaths, skinning_meshpath)
	local eid = world:create_entity {
		transform = {			
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		rendermesh = {}, 
		material = {},
		character = {
			movespeed = 1
		}, 
		physic_state = {
			velocity = {1, 0, 0},
		}, 
		state_chain = {
			ref_path = fs.path "/pkg/ant.resources/simple_animation.sm",
		},
		name = "animation_sample",
		main_view = true,
		sampleobj = true,

		can_render 	= true,
		can_select 	= true,
		can_cast 	= true,
		can_show_bounding = true,
	}

	local e = world[eid]

	if skepath then
		world:add_component(eid, "skeleton", {ref_path = skepath})
	end

	if #anipaths > 0 then
		local anilist = {}		
		for _, anipath in ipairs(anipaths) do
			anilist[#anilist+1] = {
				ref_path = anipath,
				scale = 1,
				looptimes = 0,
				name = "",
			}
		end

		world:add_component(eid, "animation", {
			pose_state = {
				pose = {
					anirefs = {
						{idx = 1, weight=1},
					},
					name = "idle",
				}
			},
			anilist = anilist,
			blendtype = "blend",
		})
	end

	
	if skinning_meshpath then
		if e.skeleton and e.animation then
			world:add_component(eid, "skinning_mesh", {ref_path = skinning_meshpath})
		end

		world:add_component(eid, "material", {
			content = {
				{ref_path = fs.path "/pkg/ant.resources/materials/skin_model_sample.material"}
			}
		})
	end

	return eid
end

return util
