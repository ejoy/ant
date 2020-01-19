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
m.require_policy "ant.bullet|collider"
m.require_policy "ant.render|mesh"
m.require_policy "ant.render|render"
m.require_policy "ant.render|name"
m.require_policy "ant.render|shadow_cast"
m.require_policy "ant.render|light.directional"
m.require_policy "ant.render|light.ambient"

m.require_system "ant.render|physic_bounding"
m.require_system "ant.imguibase|imgui_system"
m.require_interface "ant.render|camera_spawn"
m.require_interface "ant.animation|animation"
m.require_interface "ant.timer|timer"
m.require_interface "ant.camera_controller|camera_motion"
m.require_interface "ant.render|iwidget_drawer"
m.require_interface "ant.bullet|collider"

local ics = world:interface "ant.render|camera_spawn"
local iwd = world:interface "ant.render|iwidget_drawer"
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
    iwd.create()
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

local animation     = world:interface "ant.animation|animation"
local timer         = world:interface "ant.timer|timer"
local camera_motion = world:interface "ant.camera_controller|camera_motion"
local collider      = world:interface "ant.bullet|collider"

local eventKeyboard = world:sub {"keyboard"}
local eventMouse    = world:sub {"mouse","RIGHT","DOWN"}
local eventResize   = world:sub {"resize"}

local PRESS    <const> = {[0]=-1,1,0}
local DIR_NULL <const> = 5
local RADIAN   <const> = {
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
local mode
local target

local function setEntityFacing(e, facing)
	ms(e.transform.r, {type="e",0,facing,0}, "=")
end

local function setEntityPosition(e, postion)
	local srt = {
		s = e.transform.s,
		r = e.transform.r,
		t = postion,
	}
	if collider.test(e, srt) then
		return
	end
	ms(e.transform.t, postion, "=")
end

local function moveEntity(e, distance)
	local postion = ms(e.transform.t, {distance}, e.transform.r,"d*+P")
	return setEntityPosition(e, postion)
end

function m:data_changed()
	for _,w, h in eventResize:unpack() do
		screensize.w = w
		screensize.h = h
	end
	for _,what, press in eventKeyboard:unpack() do
		local v = PRESS[press]
		if what == "UP" then
			cur_direction = cur_direction + v
			mode = "keyboard"
		elseif what == "DOWN" then
			cur_direction = cur_direction - v
			mode = "keyboard"
		elseif what == "LEFT" then
			cur_direction = cur_direction - 3*v
			mode = "keyboard"
		elseif what == "RIGHT" then
			cur_direction = cur_direction + 3*v
			mode = "keyboard"
		end
	end
	for _,_,_,x,y in eventMouse:unpack() do
		mouse.x = x
		mouse.y = y
		local res = camera_motion.ray(cameraeid, mouse, screensize)
		if res.dir[2] < 0 then
			local x0 = res.origin[1] - res.dir[1]/res.dir[2]*res.origin[2]
			local z0 = res.origin[3] - res.dir[3]/res.dir[2]*res.origin[2]
			local postion = ms(player.transform.t, "T")
			local facing = math.atan(x0-postion[1], z0-postion[3])
			setEntityFacing(player, facing)
			target = {x0, 0, z0}
			mode = "mouse"
		end
	end
	if mode == "keyboard" and cur_direction == DIR_NULL then
		mode = nil
	end
	if not mode then
		animation.set_state(player, "idle")
		return
	end
	local move_speed = timer.delta() * 0.002
	if mode == "keyboard" then
		local camera = world[cameraeid].camera
		local viewdir = ms(camera.viewdir, "T")
		local facing = RADIAN[cur_direction] + math.atan(viewdir[1], viewdir[3])
		animation.set_state(player, "walking")
		setEntityFacing(player, facing)
		moveEntity(player, move_speed)
	elseif mode == "mouse" then
		local postion = ms(player.transform.t, "T")
		local dx = target[1] - postion[1]
		local dy = target[3] - postion[3]
		local dis = dx*dx+dy*dy
		if dis < 1 then
			animation.set_state(player, "idle")
			target = nil
			mode = nil
			return
		end
		iwd.draw_lines {postion, target}
		animation.set_state(player, "walking")
		if dis < move_speed * move_speed then
			moveEntity(player, math.sqrt(dis))
		else
			moveEntity(player, move_speed)
		end
	end
end
