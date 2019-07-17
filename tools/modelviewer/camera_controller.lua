local ecs = ...
local world = ecs.world

local imgui = require "imgui"

ecs.import "ant.inputmgr"

local math3d = require "math3d"

local mathpkg = import_package "ant.math"
local point2d = mathpkg.point2d
local ms = mathpkg.stack
local mu = mathpkg.util

local memmgr = import_package "ant.memory_stat"

local rhwi = import_package "ant.render".hardware_interface

local camera_controller_system = ecs.system "camera_controller"

camera_controller_system.singleton "message"
camera_controller_system.singleton "control_state"

camera_controller_system.depend "message_system"

local function camera_move(forward_axis, position, dx, dy, dz)
	--ms(position, rotation, "b", position, "S", {dx}, "*+S", {dy}, "*+S", {dz}, "*+=")	
	local right_axis, up_axis = ms:base_axes(forward_axis)
	ms(position, 
		position, 
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
	local camera_entity = world:first_entity("main_queue")

	local target = math3d.ref "vector"
	local camera = camera_entity.camera
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

	function message:mouse(what, state, x, y)
		local xy = point2d(x, y)
		if state == "MOVE" then
			if last_xy then
				if what == "RIGHT" then
					local delta = convertxy(xy - last_xy) * move_speed
					camera_move(camera.viewdir, camera.eyepos, -delta.x, delta.y, 0)
					ms(target, camera.eyepos, camera.viewdir, {distance}, '*+=')
				elseif what == "LEFT" then
					local delta = convertxy(xy - last_xy) * rotation_speed
					rotate_round_point(camera, target, distance, delta.x, delta.y)
				end
			end
		elseif state == "DOWN" then
			distance = math.sqrt(ms(target, camera.eyepos, "-1.T")[1])
		end
		last_xy = xy
	end

	local touchState = "NONE"
	local touchFinger1
	local touchFinger2
	function message:touch(id, state, x, y)
		if state ~= "MOVE" then
			print(touchState, id, state, x, y)
		end
		if touchState == "NONE" then
			if state == "DOWN" then
				touchFinger1 = id
				touchState = "PAN"
				message:mouse("RIGHT", "DOWN", x, y)
			end
		elseif touchState == "PAN" then
			if state == "DOWN" then
				touchFinger2 = id
				touchState = "PANIC"
				message:mouse("RIGHT", "UP", x, y)
			elseif state == "UP" then
				touchFinger1 = nil
				touchState = "NONE"
				message:mouse("RIGHT", "UP", x, y)
			else
				message:mouse("RIGHT", "MOVE", x, y)
			end
		elseif touchState == "PANIC" then
			if state == "DOWN" then
			elseif state == "UP" then
				if touchFinger1 == id then
					touchFinger1 = touchFinger2
					touchFinger2 = nil
					touchState = "PAN"
					message:mouse("RIGHT", "DOWN", x, y)
				elseif touchFinger2 == id then
					touchFinger2 = nil
					touchState = "PAN"
					message:mouse("RIGHT", "DOWN", x, y)
				end
			else
				-- TODO
			end
		end
	end

	function message:mouse_wheel(_, _, delta)
		camera_move(camera.viewdir, camera.eyepos, 0, 0, delta * wheel_speed)
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
    local memstat = memmgr.bgfx_stat("m")
    local s = {"memory:"}
    local keys = {}
    for k in pairs(memstat) do
        keys[#keys+1] = k
    end
    table.sort(keys, function(lhs, rhs) return lhs < rhs end)
    for _, k in ipairs(keys) do
        local v = memstat[k]
        s[#s+1] = "\t" .. k .. ":" .. v
    end

    return table.concat(s, "\n")
end


function camera_controller_system:update()
	local windows = imgui.windows
	local widget = imgui.widget
	local flags = imgui.flags
	imgui.begin_frame(1/60)
	windows.SetNextWindowSizeConstraints(300, 300, 500, 500)
	windows.Begin("Test", flags.Window { "MenuBar" })
	widget.Text(memory_info())
	windows.End()
	imgui.end_frame()
end
