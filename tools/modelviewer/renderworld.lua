local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local renderpkg = import_package "ant.render"
local skypkg = import_package "ant.sky"
local fs = require "filesystem"

local skyutil = skypkg.util
local mu = mathpkg.util
local mc = mathpkg.constant
local ms = mathpkg.stack

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

m.require_system "ant.sky|procedural_sky_system"

m.require_system "ant.imguibase|imgui_system"
m.require_interface "ant.render|camera_spawn"

local ics = world:interface "ant.render|camera_spawn"

local function create_light()
	lu.create_directional_light_entity(world, "direction light", {1,1,1,1}, 2, mu.to_radian{60, 50, 0, 0})
	lu.create_ambient_light_entity(world, "ambient light", 'color', {1, 1, 1, 1}, {0.9, 0.9, 1, 1}, {0.60,0.74,0.68,1})
end

local function create_camera()
    local fbsize = world.args.fb_size
    local frustum = defaultcomp.frustum(fbsize.w, fbsize.h)
	frustum.f = 300
	ics.bind("main_queue", ics.spawn("test_main_camera", {
        type    = "",
        eyepos  = {0, 3, -10, 1},
        viewdir = mc.T_ZAXIS,
        updir   = mc.T_YAXIS,
        frustum = frustum,
    }))
end

function m:post_init()
	create_camera()
end

local player
function m:init()
	
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
	local eid = world:create_entity(load_file 'res/player.txt')
	player = world[eid]
end

m.require_interface "ant.animation|animation"
m.require_interface "ant.timer|timer"

local renderpkg = import_package "ant.render"
local camerautil= renderpkg.camera

local animation = world:interface "ant.animation|animation"
local eventKeyboard = world:sub {"keyboard"}
local PRESS <const> = {[0]=-1,1,0}
local DIR_NULL      <const> = 5
local cur_direction = DIR_NULL
local RADIAN <const> = {
	math.rad(225), --SOUTHWEST
	math.rad(270), --WEST
	math.rad(315), --NORTHWEST
	math.rad(180), --SOUTH
	math.rad(  0), --NULL
	math.rad(  0), --NORTH
	math.rad(135), --SOUTHEAST
	math.rad( 90), --EAST
	math.rad( 45), --NORTHEAST
}

function m:ui_update()
	for _,what, press in eventKeyboard:unpack() do
		local v = PRESS[press]
		if what == "UP" then
			cur_direction = cur_direction + v
		elseif what == "DOWN" then
			cur_direction = cur_direction - v
		elseif what == "LEFT" then
			cur_direction = cur_direction - 3*v
		elseif what == "RIGHT" then
			cur_direction = cur_direction + 3*v
		end
	end
	if cur_direction == DIR_NULL then
		animation.set_state(player, "idle")
		return
	end
	local camera = camerautil.main_queue_camera(world)
	local viewdir = ms(camera.viewdir, "T")
	local radian = RADIAN[cur_direction] + math.atan(viewdir[1], viewdir[3])
	animation.set_state(player, "walking")
	local delta = world:interface "ant.timer|timer".delta() / 1000
	local srt = player.transform
	ms(srt.r, {type="e",0,radian,0}, "=")
	ms(srt.t, srt.t, {2*delta}, srt.r,"d*+=")
end
