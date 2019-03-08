local util = {}; util.__index = util

local geometry = import_package "ant.geometry"
local geo = geometry.geometry

local pfs = require "filesystem.pkg"
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

function util.create_aabb_widget(e)	
	local descs = util.create_aabb_mesh_info(e.mesh)
	if #descs == 0 then
		return 
	end

	local ibhandle = bgfx.create_index_buffer(descs[1].ib)
	local decl = bgfx.vertex_decl {
		{ "POSITION", 3, "FLOAT" },		
	}

	local function create_mesh_groups(descs)
		local groups = {}
		for _, desc in ipairs(descs) do
			local vb = {"fff",}
			for _, v in ipairs(desc.vb) do
				for _, vv in ipairs(v) do
					table.insert(vb, vv)
				end
			end

			table.insert(groups, {
					vb = {handles = {bgfx.create_vertex_buffer(vb, decl)}},
					ib = {handle = ibhandle},
				})
		end

		return groups
	end

	local widget = e.widget
	widget.mesh = {
		assetinfo = {
			handle = {
				groups = create_mesh_groups(descs, 0xffff0000),
			}
		}
	}
end

function util.create_sample_entity(world, skepath, anipaths, skinning_meshpath)
	local eid = world:create_entity {
		transform = {			
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		mesh = {}, 
		material = {},
		can_render = true,
		sampleobj = true,
		character = {
			movespeed = 1
		}, 
		physic_state = {
			velocity = {1, 0, 0},
		}, 
		state_chain = {
			ref_path = pfs.path "//ant.resources/simple_animation.sm",
		},
		name = "animation_sample",
		main_viewtag = true,
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
				{ref_path = pfs.path "//ant.resources/skin_model_sample.material"}
			}
		})
	
		world:add_component(eid, "widget", {
			material = {
				content = {
					{
						ref_path = pfs.path "//ant.resources/line.material"
					}
				}
			},
			mesh = {},
			srt = {
				s = {1, 1, 1, 0},
				r = {0, 0, 0, 0},
				t = {0, 0, 0, 1},
			}
		})
	end

	return eid
end

return util
