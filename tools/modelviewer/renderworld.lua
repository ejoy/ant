local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local renderpkg = import_package "ant.render"
local skypkg = import_package "ant.sky"
local fs = require "filesystem"

local skyutil = skypkg.util
local mu = mathpkg.util
local mc = mathpkg.constant

local lu = renderpkg.light
local cu = renderpkg.components
local defaultcomp = renderpkg.default

local m = ecs.system "model_review_system"

m.require_policy "ant.sky|procedural_sky"
m.require_policy "ant.serialize|serialize"
m.require_policy "ant.bullet|collider.capsule"
m.require_policy "ant.render|mesh"
m.require_policy "ant.render|render"
m.require_policy "ant.render|name"
m.require_policy "ant.render|shadow_cast"
m.require_policy "ant.render|light.directional"
m.require_policy "ant.render|light.ambient"
m.require_system "ant.camera_controller|camera_system"

local function create_light()
	lu.create_directional_light_entity(world, "direction light", {1,1,1,1}, 2, mu.to_radian{60, 50, 0, 0})
	lu.create_ambient_light_entity(world, "ambient light", 'color', {1, 1, 1, 1}, {0.9, 0.9, 1, 1}, {0.60,0.74,0.68,1})
end

local function create_camera()
    local fbsize = world.args.fb_size
    local frustum = defaultcomp.frustum(fbsize.w, fbsize.h)
    frustum.f = 300
    world:pub {"spawn_camera", "test_main_camera", {
        type    = "",
        eyepos  = {0, 3, -10, 1},
        viewdir = mc.T_ZAXIS,
        updir   = mc.T_YAXIS,
        frustum = frustum,
    }}
end

function m:init()
	create_camera()
	create_light()
	skyutil.create_procedural_sky(world, {follow_by_directional_light=false})
	cu.create_plane_entity(
		world,
		mu.srt{50, 1, 50, 0},
		fs.path "/pkg/ant.resources/depiction/materials/test/mesh_shadow.material",
		{0.8, 0.8, 0.8, 1},
		"test shadow plane"
	)

	local function load_file(file)
		local f = assert(fs.open(fs.path(file), 'r'))
		local data = f:read 'a'
		f:close()
		return data
	end
	world:create_entity(load_file 'res/door.txt')
	world:create_entity(load_file 'res/fence.txt')
	world:create_entity(load_file 'res/player.txt')
end
