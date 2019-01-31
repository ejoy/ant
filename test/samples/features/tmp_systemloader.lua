local ecs = ...
local world = ecs.world

local fs = require "filesystem"

ecs.import "ant.render"
ecs.import "ant.editor"
ecs.import "ant.inputmgr"
ecs.import "ant.serialize"
ecs.import "ant.scene"
ecs.import "ant.timer"
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
	local meshdir = fs.path "meshes"
	local skepath = meshdir / "skeleton" / "human_skeleton.ozz"
	local anipaths = {
		meshdir / "animation" / "animation1.ozz",
		meshdir / "animation" / "animation2.ozz",
	}

	local smpath = meshdir / "mesh.ozz"

	local anitest_eid = world:new_entity(
		"position", "scale", "rotation",
		"can_render", "mesh", "material",
		"animation", "skeleton", "skinning_mesh",
		"name")

	local anitest = world[anitest_eid]
	anitest.name = "animation_entity"

	mathutil.identify_transform(anitest)	
	computil.load_skinning_mesh(anitest.skinning_mesh, anitest.mesh, "ant.resources", smpath)
	computil.load_skeleton(anitest.skeleton, "ant.resources", skepath)
	

	aniutil.init_animation(anitest.animation, anitest.skeleton)
	local weight = 1 / #anipaths
	for _, anipath in ipairs(anipaths) do
		aniutil.add_animation(anitest.animation, "ant.resources", anipath, weight)
	end

	computil.add_material(anitest.material, "ant.resources", fs.path "skin_model_sample.material")
end

local serialize = import_package "ant.serialize"

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

	local t1 = serialize.save(world)
	local s = serialize.stringify(world, t1)
	local nativeio = require 'nativeio'
	assert(assert(nativeio.open('D:\\work\\ant\\serialize.txt', 'w')):write(s)):close()
	for _, eid in world:each "serialize" do
		world:remove_entity(eid)
	end
	serialize.load(world, s)
end
