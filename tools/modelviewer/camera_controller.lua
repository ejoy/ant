local ecs = ...
local world = ecs.world

local imgui = require "imgui"

ecs.import "ant.inputmgr"

local math3d = require "math3d"

local mathpkg = import_package "ant.math"
local point2d = mathpkg.point2d
local ms = mathpkg.stack
local mu = mathpkg.util

local renderpkg = import_package "ant.render"
local camerautil= renderpkg.camera

local memmgr = import_package "ant.memory_stat"

local rhwi = import_package "ant.render".hardware_interface

local camera_controller_system = ecs.system "camera_controller"

camera_controller_system.singleton "message"
camera_controller_system.singleton "control_state"

camera_controller_system.depend "message_system"
camera_controller_system.depend "imgui_runtime_system"

local function camera_move(forward_axis, position, dx, dy, dz)
	local right_axis, up_axis = ms:base_axes(forward_axis)
	ms(position, position, 
			right_axis, {dx}, "*+", 
			up_axis, {dy}, "*+", 
			forward_axis, {dz}, "*+=")
end

local function camera_reset(camera, target)
	ms(target, {0, 0, 0, 1}, "=")
	ms(camera.eyepos, {8, 8, -8, 1}, "=")
	ms(camera.viewdir, target, camera.eyepos, "-n=")
end

local function rotate_round_point(camera, point, distance, dx, dy)	
	local right, up = ms:base_axes(camera.viewdir)

	if ms:is_parallel(mu.YAXIS, camera.viewdir, 0.05) then	
		ms(camera.viewdir,
		{type="q", axis=up, radian={dx}}, 
		camera.viewdir,
		"*n=")								-- get view dir from point to camera position, than multipy with rotation quternion
	else
		ms(camera.viewdir,
		{type="q", axis=up, radian={dx}}, 
		{type="q", axis=right, radian={dy}},	-- rotation quternion in stack
		"3**n=")								-- get view dir from point to camera position, than multipy with rotation quternion
	end
	ms(camera.eyepos, point, camera.viewdir, {distance}, '*-=')	--calculate new camera position: point - viewdir * distance
end

function camera_controller_system:init()	
	local mq = world:first_entity "main_queue"

	local target = math3d.ref "vector"
	local camera = camerautil.get_camera(world, mq.camera_tag)
	camera_reset(camera, target)

	local move_speed = 10
	local rotation_speed = 1
	local wheel_speed = 1
	local distance
	local last_xy
	local xdpi, ydpi = rhwi.dpi()

	local function convertxy(p2d)
		p2d.x = p2d.x / xdpi
		p2d.y = p2d.y / ydpi
		return p2d
	end
	
	local message = {}

	function message:mouse(x, y, what, state)
		if state == "MOVE" then
			local xy = point2d(x, y)
			if last_xy then
				if what == "RIGHT" then
					local delta = convertxy(xy - last_xy) * move_speed
					local dx, dy = -delta.x, delta.y
					local right_axis, up_axis = ms:base_axes(camera.viewdir)
					local t = ms(target, 'T');t[1] = 0;t[3] = 0
					ms(camera.eyepos, camera.eyepos, right_axis, {dx}, "*+", up_axis, {dy}, "*+", t, "-=")
					ms(target, camera.eyepos, camera.viewdir, {distance}, '*+=')
				elseif what == "LEFT" then
					local delta = convertxy(xy - last_xy) * rotation_speed
					rotate_round_point(camera, target, distance, delta.x, delta.y)
				end
			end
			last_xy = xy
		elseif state == "DOWN" then
			last_xy = point2d(x, y)
			distance = math.sqrt(ms(target, camera.eyepos, "-1.T")[1])
		end
	end

	local touchState = "NONE"
	local touchf1 = {}
	local touchf2 = {}
	local touchAngle
	local touchDistance

	local function calcAngleAndDistance()
		local dx = touchf1.x - touchf2.x
		local dy = touchf1.y - touchf2.y
		return math.atan(dy, dx), math.sqrt(dx*dx+dy*dy)
	end

	function message:touch(x, y, id, state)
		if touchState == "NONE" then
			if state == "DOWN" then
				touchf1.id = id
				touchf1.x = x
				touchf1.y = y
				touchState = "PAN"
				message:mouse("RIGHT", "DOWN", x, y)
			end
		elseif touchState == "PAN" then
			if state == "DOWN" then
				touchf2.id = id
				touchf2.x = x
				touchf2.y = y
				touchAngle, touchDistance = calcAngleAndDistance()
				touchState = "PANIC"
				message:mouse("RIGHT", "UP", x, y)
			elseif state == "UP" then
				touchf1.id = nil
				touchState = "NONE"
				message:mouse("RIGHT", "UP", x, y)
			else
				touchf1.x = x
				touchf1.y = y
				message:mouse("RIGHT", "MOVE", x, y)
			end
		elseif touchState == "PANIC" then
			if state == "DOWN" then
			elseif state == "UP" then
				if touchf1.id == id then
					touchf1.id = touchf2.id
					touchf1.x = touchf2.x
					touchf1.y = touchf2.y
					touchf2.id = nil
					touchState = "PAN"
					message:mouse("RIGHT", "DOWN", touchf1.x, touchf1.y)
				elseif touchf2.id == id then
					touchf2.id = nil
					touchState = "PAN"
					message:mouse("RIGHT", "DOWN", touchf1.x, touchf1.y)
				end
			else
				if touchf1.id == id then
					touchf1.x = x
					touchf1.y = y
				elseif touchf2.id == id then
					touchf2.x = x
					touchf2.y = y
				end
				local angle, distance = calcAngleAndDistance()
				local scale = distance / touchDistance
				local rotation = angle - touchAngle
				touchAngle, touchDistance = angle, distance

				message:mouse_wheel(nil, nil, (scale-1)*20)
			end
		end
	end

	function message:mouse_wheel(_, _, delta)
		local dz = delta * wheel_speed
		ms(camera.eyepos, camera.eyepos, camera.viewdir, {dz}, "*+=")
	end

	function message:keyboard(code, press)
		if press and code == "R" then
			camera_reset(camera, target)
			return 
		end

		if press and code == "SPACE" then
			for _, eid in world:each "can_render" do
				local e = world[eid]
				if e.name == "frustum" then
					world:remove_entity(eid)
				end
			end

			local computil = import_package "ant.render".components
			local _, _, vp = ms:view_proj(camera, camera.frustum, true)
			local mathbaselib = require "math3d.baselib"
			local frustum = mathbaselib.new_frustum(ms, vp)
			computil.create_frustum_entity(world, frustum)
		end
	end

	function message:resize(w, h)
		rhwi.reset(nil, w, h)
	end

	self.message.observers:add(message)
end


local function memory_info()
	local s = {}
	local platform = require "platform"
	local bgfx = require "bgfx"
	s[#s+1] = ""
	s[#s+1] = ("sys  memory:%.1fMB"):format(platform.info "memory" / 1024.0 / 1024.0)
	s[#s+1] = ("lua  memory:%.1fMB"):format(collectgarbage "count" / 1024.0)

	local memory = bgfx.get_stats "a"
	s[#s+1] = ("bgfx memory:%.1fMB"):format(memory / 1024.0 / 1024.0)

	s[#s+1] = "-------------------"

	local data = bgfx.get_stats "m"
	s[#s+1] = ("rt   memory:%.1fMB"):format(data.rtMemoryUsed / 1024.0 / 1024.0)
	s[#s+1] = ("tex  memory:%.1fMB"):format(data.textureMemoryUsed / 1024.0 / 1024.0)

	return table.concat(s, "\n\t")
end

function camera_controller_system:on_gui()
	local windows = imgui.windows
	local widget = imgui.widget
	local flags = imgui.flags
	windows.SetNextWindowSizeConstraints(300, 300, 500, 500)
	windows.Begin("Test", flags.Window { "MenuBar" })
	widget.Text(memory_info())
	windows.End()
end

function camera_controller_system:update()
	
end
