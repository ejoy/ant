local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local renderpkg = import_package "ant.render"
local skypkg = import_package "ant.sky"
local fs = require "filesystem"
local task = require "task"
local math3d = require "math3d"

local skyutil = skypkg.util
local mu = mathpkg.util

local lu = renderpkg.light
local cu = renderpkg.components

local m = ecs.system "model_viewer"

m.require_policy "ant.sky|procedural_sky"
m.require_policy "ant.serialize|serialize"
m.require_policy "ant.collision|collider"
m.require_policy "ant.render|mesh"
m.require_policy "ant.render|render"
m.require_policy "ant.render|name"
m.require_policy "ant.render|shadow_cast"
m.require_policy "ant.render|light.directional"
m.require_policy "ant.render|light.ambient"

m.require_system "ant.render|physic_bounding"
m.require_system "ant.imguibase|imgui_system"
m.require_interface "ant.render|camera"
m.require_interface "ant.animation|animation"
m.require_interface "ant.timer|timer"
m.require_interface "ant.camera_controller|camera_motion"
m.require_interface "ant.render|iwidget_drawer"
m.require_interface "ant.collision|collider"

local camera = world:interface "ant.render|camera"
local iwd = world:interface "ant.render|iwidget_drawer"
local animation = world:interface "ant.animation|animation"
local camera_id

local function create_light()
	lu.create_directional_light_entity(world, "direction light", {1,1,1,1}, 2, math3d.quaternion(math.rad(60), math.rad(50), 0))
	lu.create_ambient_light_entity(world, "ambient light", 'color', {1, 1, 1, 1}, {0.9, 0.9, 1, 1}, {0.60,0.74,0.68,1})
end

local function create_camera()
	camera_id = camera.create {
        eyepos  = {0,10,-24,1},
        viewdir = {0,-1,1,0}
    }
	camera.bind(camera_id, "main_queue")
end

function m:post_init()
	create_camera()
end

local player
function m:init()
	create_light()
	skyutil.create_procedural_sky(world)
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

local timer         = world:interface "ant.timer|timer"
local camera_motion = world:interface "ant.camera_controller|camera_motion"
local collider      = world:interface "ant.collision|collider"

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
local move_speed = 200

local function setEntityFacing(e, facing)
	e.transform.r.q = math3d.quaternion(0, facing, 0)
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
	e.transform.t.v = postion
	return true
end

local function moveEntity(e, distance)
	local postion = math3d.muladd(distance, math3d.todirection(e.transform.r), e.transform.t)
	if setEntityPosition(e, postion) then
		local camera_data = camera.get(camera_id)
		camera_data.eyepos.v = math3d.muladd(math3d.todirection(e.transform.r), distance, camera_data.eyepos)
	end
end

local function mainloop(delta)
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
		elseif what == "SPACE" then
			if press == 1 then
				if mode ~= "attack" then
					local tmp = mode
					mode = "attack"
					animation.set_state(player, "attack")
					task.wait(1000)
					mode = tmp
					if mode == "idle" then
						animation.set_state(player, "idle")
					else
						animation.set_state(player, "move")
					end
				end
			end
			return
		end
	end
	for _,_,_,x,y in eventMouse:unpack() do
		mouse.x = x
		mouse.y = y
		local res = camera_motion.ray(camera_id, mouse, screensize)
		if res.dir[2] < 0 then
			local x0 = res.origin[1] - res.dir[1]/res.dir[2]*res.origin[2]
			local z0 = res.origin[3] - res.dir[3]/res.dir[2]*res.origin[2]
			local postion = math3d.totable(player.transform.t)
			local facing = math.atan(x0-postion[1], z0-postion[3])
			setEntityFacing(player, facing)
			target = {x0, 0, z0}
			mode = "mouse"
		end
	end
	if mode == "keyboard" and cur_direction == DIR_NULL then
		mode = "idle"
		animation.set_state(player, "idle")
	end
	local move_distance = delta * move_speed / 100000
	if mode == "keyboard" then
		local camera_data = camera.get(camera_id)
		local viewdir = math3d.totable(camera_data.viewdir)
		local facing = RADIAN[cur_direction] + math.atan(viewdir[1], viewdir[3])
		animation.set_state(player, "move")
		setEntityFacing(player, facing)
		moveEntity(player, move_distance)
	elseif mode == "mouse" then
		local postion = math3d.totable(player.transform.t)
		local dx = target[1] - postion[1]
		local dy = target[3] - postion[3]
		local dis = dx*dx+dy*dy
		if dis < 1 then
			mode = "idle"
			animation.set_state(player, "idle")
			target = nil
			return
		end
		iwd.draw_lines {postion, target}
		animation.set_state(player, "move")
		if dis < move_distance * move_distance then
			moveEntity(player, math.sqrt(dis))
		else
			moveEntity(player, move_distance)
		end
	end
end

local excess_tick = 0

function m:data_changed()
	local tick = excess_tick + timer.delta()
	local delta = math.floor(tick)
	excess_tick = tick - delta
	task.add(function()
		return mainloop(delta)
	end)
	task.update(delta)
end

local imgui = require "imgui.ant"
local imgui_util = require "imgui_util"

local m = ecs.system "gui"

m.require_system "ant.imguibase|imgui_system"

local wndflags = imgui.flags.Window {  }

local imguiMoveSpeed = {move_speed, min = 0, max = 600}

function m:ui_update()
	imgui.windows.SetNextWindowPos(800,0)
	imgui.windows.SetNextWindowSize(200,200)
	for _ in imgui_util.windows("GUI", wndflags) do
		if imgui.widget.SliderInt("Move Speed", imguiMoveSpeed) then
			move_speed = imguiMoveSpeed[1]
			animation.set_value(player, "move", "move_speed", move_speed)
		end
	end
end
