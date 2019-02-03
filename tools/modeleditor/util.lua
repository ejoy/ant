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
	local eid = world:new_entity("position", "scale", "rotation",		
	"mesh", "material", "can_render",
	"sampleobj", "character", "physic_state", "state_chain",
	"name")

	local e = world[eid]
	e.name = "animation_test"

	mu.identify_transform(e)

	local emptypath = fs.path ""

	if skepath.filename ~= emptypath then
		world:add_component(eid, "skeleton")
		computil.load_skeleton(e.skeleton, skepath.package, skepath.filename)
	end

	if #anipaths > 0 then
		world:add_component(eid, "animation")
		local anicomp = e.animation
		aniutil.init_animation(anicomp, e.skeleton)		
		local anipose = anicomp.pose
		local define = anipose.define
		
		for _, anipath in ipairs(anipaths) do
			aniutil.add_animation(anicomp, anipath)
		end		
		define.anilist = {
			{idx=1, weight=1}
		}
		define.name = "idle"
	end

	
	if skinning_meshpath.filename ~= emptypath then
		if e.skeleton and e.animation then
			world:add_component(eid, "skinning_mesh")
			computil.load_skinning_mesh(e.skinning_mesh, e.mesh, skinning_meshpath.package, skinning_meshpath.filename)
		end

		computil.add_material(e.material, "ant.resources", samplematerialpath)
	
		add_aabb_widget(world, eid)
	end

	return eid
end

return util
