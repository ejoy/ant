local util = {}; util.__index = util

local geometry = import_package "ant.geometry"
local geo = geometry.geometry

local computil = (import_package "ant.render").components
local aniutil = (import_package "ant.animation").util

local fs = require "filesystem"

local math = import_package "ant.math"
local mu = math.util
local bgfx = require "bgfx"

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

local function add_aabb_widget(world, eid)
	world:add_component(eid, "widget")
	local e = world[eid]
	local aabb_material = fs.path "line.material"
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

	local material = {}
	computil.add_material(material, "ant.resources", aabb_material)
	widget.material = material

	widget.srt = {}--{s=e.scale, r=nil, t=e.position}
end

local samplematerialpath = fs.path "skin_model_sample.material"

function util.create_sample_entity(world, skepath, anipaths, skinning_meshpath)
	local eid = world:create_entity {
		position = {0, 0, 0, 1}, 
		scale = {1, 1, 1, 0}, 
		rotation = {0, 0, 0, 0},
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
			ref_path = {package="ant.resources", filename = fs.path "simple_animation.sm"},
		},
		name = "animation_sample"
	}

	local e = world[eid]
	local emptypath = fs.path ""

	if skepath.filename ~= emptypath then
		world:add_single_component(eid, "skeleton", {ref_path = skepath})
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

		world:add_single_component(eid, "animation", {
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

	
	if skinning_meshpath.filename ~= emptypath then
		if e.skeleton and e.animation then
			world:add_single_component(eid, "skinning_mesh", {ref_path = skinning_meshpath})
		end

		world:add_single_component(eid, "material", {
			content = {
				{ref_path = {package = "ant.resources", filename = samplematerialpath}}
			}
		})
	
		--add_aabb_widget(world, eid)
	end

	return eid
end

return util
