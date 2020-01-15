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

m.require_system "ant.render|physic_bounding"
m.require_system "ant.imguibase|imgui_system"
m.require_interface "ant.render|camera_spawn"

local ics = world:interface "ant.render|camera_spawn"
local cameraeid

local function create_light()
	lu.create_directional_light_entity(world, "direction light", {1,1,1,1}, 2, mu.to_radian{60, 50, 0, 0})
	lu.create_ambient_light_entity(world, "ambient light", 'color', {1, 1, 1, 1}, {0.9, 0.9, 1, 1}, {0.60,0.74,0.68,1})
end

local function create_camera()
    local fbsize = world.args.fb_size
    local frustum = defaultcomp.frustum(fbsize.w, fbsize.h)
	frustum.f = 300
	cameraeid = ics.spawn("test_main_camera", {
        type    = "",
        eyepos  = {0, 3, -20, 1},
        viewdir = mc.T_ZAXIS,
        updir   = mc.T_YAXIS,
        frustum = frustum,
    })
	ics.bind("main_queue", cameraeid)
end

function m:post_init()
	create_camera()
end

local player
function m:init()
	create_light()
	skyutil.create_procedural_sky(world, {follow_by_directional_light=false})
    cu.create_bounding_drawer(world)
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
	world:create_entity(load_file 'res/fence1.txt')
	world:create_entity(load_file 'res/fence2.txt')
	local eid = world:create_entity(load_file 'res/player.txt')
	player = world[eid]
end

m.require_interface "ant.animation|animation"
m.require_interface "ant.timer|timer"
m.require_interface "ant.camera_controller|camera_motion"

local animation = world:interface "ant.animation|animation"
local timer = world:interface "ant.timer|timer"
local camera_motion = world:interface "ant.camera_controller|camera_motion"

local eventKeyboard = world:sub {"keyboard"}
local eventMouse = world:sub {"mouse","LEFT","DOWN"}
local eventResize = world:sub {"resize"}

local PRESS <const> = {[0]=-1,1,0}
local DIR_NULL      <const> = 5
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

local cur_direction = DIR_NULL
local screensize = {w=0,h=0}
local mouse = {x=0,y=0}

local function setEntityFacing(e, facing)
	ms(e.transform.r, {type="e",0,facing,0}, "=")
end

local function setEntityPosition(e, postion)
	ms(e.transform.t, postion, "=")
end

local function moveEntity(e, distance)
	local postion = ms(e.transform.t, {distance}, e.transform.r,"d*+P")
	return setEntityPosition(e, postion)
end

function m:ui_update()
	local walking
	for _,w, h in eventResize:unpack() do
		screensize.w = w
		screensize.h = h
	end
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
	for _,_,_,x,y in eventMouse:unpack() do
		mouse.x = x
		mouse.y = y
		local res = camera_motion.ray(cameraeid, mouse, screensize)
		if res.dir[2] ~= 0 then
			local x0 = res.origin[1] - res.dir[1]/res.dir[2]*res.origin[2]
			local z0 = res.origin[3] - res.dir[3]/res.dir[2]*res.origin[2]
			walking = math.atan(x0, z0)
		end
	end
	if not walking and cur_direction ~= DIR_NULL then
		local camera = world[cameraeid].camera
		local viewdir = ms(camera.viewdir, "T")
		walking = RADIAN[cur_direction] + math.atan(viewdir[1], viewdir[3])
	end
	if not walking then
		animation.set_state(player, "idle")
		return
	else
		animation.set_state(player, "walking")
	end
	setEntityFacing(player, walking)
	moveEntity(player, timer.delta() * 0.002)
end
