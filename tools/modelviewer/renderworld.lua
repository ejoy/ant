local ecs = ...
local world = ecs.world

local computil = world:interface "ant.render|entity"

local fs 		= require "filesystem"
local task 		= require "task"
local math3d 	= require "math3d"

local m = ecs.system "model_viewer_system"

local camera = world:interface "ant.scene|camera"
local iwd = world:interface "ant.render|iwidget_drawer"
local animation = world:interface "ant.animation|animation"
local camera_id

local ilight = world:interface "ant.render|light"
local imaterial = world:interface "ant.asset|imaterial"

local function create_light()
	local rotator = math3d.quaternion{math.rad(60), 0, 0}
	local dir = math3d.todirection(rotator)
	local dlightdir = math3d.totable(math3d.normalize(math3d.inverse(dir)))
	local pos = {0, 0, 0, 1}
	ilight.create_directional_light_entity("direction light", {1,1,1,1}, 2, dlightdir, pos)
	ilight.create_ambient_light_entity("ambient light", 'color', {1, 1, 1, 1}, {0.9, 0.9, 1, 1}, {0.60,0.74,0.68,1})
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
	computil.create_procedural_sky()
	local eid = computil.create_plane_entity(
		{s = {50, 1, 50, 0}},
		"/pkg/ant.resources/materials/mesh_shadow.material",
		"test shadow plane"
	)

	imaterial.set_property(eid, "u_basecolor_factor", {0.8, 0.8, 0.8, 1})
	world:create_entity 'res/door.txt'
	world:create_entity 'res/fence1.txt'
	world:create_entity 'res/fence2.txt'
	local eid = world:create_entity 'res/player.txt'
	player = world[eid]
end

local timer     = world:interface "ant.timer|timer"
local iom 		= world:interface "ant.objcontroller|obj_motion"
local collider  = world:interface "ant.collision|collider"

local eventKeyboard = world:sub {"keyboard"}
local eventMouse    = world:sub {"mouse","RIGHT","DOWN"}

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
local mouse = {0,0}
local mode
local target
local move_speed = 200

local function setEntityFacing(e, facing)
	e.transform.r = math3d.quaternion{0, facing, 0}
end

local function setEntityPosition(e, postion)
	local s, r, t = math3d.srt(e.transform)
	local srt_test = {
		s = s,
		r = r,
		t = postion,
	}
	if collider.test(e, srt_test) then
		return
	end
	e.transform.t = postion
	return true
end

local function moveEntity(e, distance)
	local s, r, t = math3d.srt(e.transform)
	local d = math3d.todirection(r)
	local postion = math3d.muladd(distance, d, t)
	if setEntityPosition(e, postion) then
		iom.move_along_axis(camera_id, d, distance)
	end
end

local function mainloop(delta)
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
		mouse[1] = x
		mouse[2] = y
		local res = iom.ray(camera_id, mouse)
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

local gui_sys = ecs.system "gui_system"

local wndflags = imgui.flags.Window {  }

local imguiMoveSpeed = {move_speed, min = 0, max = 600}

function gui_sys:ui_update()
	imgui.windows.SetNextWindowPos(800,0)
	imgui.windows.SetNextWindowSize(200,200)
	for _ in imgui_util.windows("GUI", wndflags) do
		if imgui.widget.SliderInt("Move Speed", imguiMoveSpeed) then
			move_speed = imguiMoveSpeed[1]
			animation.set_value(player, "move", "move_speed", move_speed)
		end
	end
end
