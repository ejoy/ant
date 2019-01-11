local ecs = ...
local world = ecs.world

ecs.import "ant.render"
ecs.import "ant.editor"
ecs.import "ant.inputmgr"
ecs.import "ant.serialize"
ecs.import "ant.scene"
ecs.import "ant.timer"
ecs.import "ant.objcontroller"
ecs.import "ant.hierarchy.offline"
ecs.import "ant.bullet"
ecs.import "ant.animation"

local renderpkg = import_package "ant.render"
local computil = renderpkg.components
local aniutil = import_package "ant.animation".util

local lu = renderpkg.light
local PVPScenLoader = require "PVPSceneLoader"
local asset = import_package "ant.asset"
local mathutil = import_package "ant.math" .util
local init_loader = ecs.system "init_loader"

init_loader.depend "shadow_primitive_filter_system"
init_loader.depend "transparency_filter_system"
init_loader.depend "entity_rendering"
init_loader.depend "camera_controller"
init_loader.depend "skinning_system"


local function create_animation_test()
	local assetdir = asset.assetdir()
	local skepath = assetdir / "meshes" / "skeleton" / "human_skeleton.ozz"
	local anipaths = {
		assetdir / "meshes" / "animation" / "animation1.ozz",
		assetdir / "meshes" / "animation" / "animation2.ozz",
	}

	local smpath = assetdir / "meshes" / "mesh.ozz"

	local anitest_eid = world:new_entity(
		"position", "scale", "rotation",
		"can_render", "mesh", "material",
		"animation", "skeleton", "skinning_mesh",
		"name")

	local anitest = world[anitest_eid]
	anitest.name = "animation_entity"

	mathutil.identify_transform(anitest)

	computil.load_skinning_mesh(anitest.skinning_mesh, anitest.mesh, smpath)
	computil.load_skeleton(anitest.skeleton, skepath)
	

	aniutil.init_animation(anitest.animation, anitest.skeleton)
	local weight = 1 / #anipaths
	for _, anipath in ipairs(anipaths) do
		aniutil.add_animation(anitest.animation, anipath, weight)
	end

	computil.load_material(anitest.material, {asset.depictiondir() / "skin_model_sample.material"})
end


function init_loader:init()
	do
		lu.create_directional_light_entity(world, "directional_light")
		lu.create_ambient_light_entity(world, "ambient_light", "gradient", {1, 1, 1,1})
	end

	do
		PVPScenLoader.create_entitices(world)
	end

	computil.create_grid_entity(world, "grid", 64, 64, 1)

	create_animation_test()
end
