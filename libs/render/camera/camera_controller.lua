local ecs = ...
local ru = require "render.render_util"
local world = ecs.world
local math3d = require "math3d"

local function move_along_direction(transform, step, speed)
	speed = speed or 1
	local thestep = step * speed;

	-- camera_transform.eye = stack(camera_transform.direction, {thestep, thestep, thestep, 1}, "*P", -- direction * theStep =>stackTop
	-- 							 camera_transform.eye, "+M")	-- stackTop + eye
end

local function move_horizontal_and_vertical(transform, step, speed)
	speed = speed or 1

end

local function rotate(transform, step, speed)
	speed = speed or 1
	local theStep = step * speed

end

local function update_camera_trans(camera, m, speed)
	--[@ rotate camera
	local btn = assert(m.button_event)
	local last_btn = m.button_last_event

	local motion = assert(m.motion_event)
	local last_motion = m.motion_last_event

	local keys = assert(m.keypress_event)
	local last_keys = m.keypress_last_event


	if btn.type == "LEFT" then
		local deltaX = last_motion and (motion.x - last_motion.x) or 0
		local deltaY = last_motion and (motion.y - last_motion.y) or 0

		if deltaX ~= 0 or deltaY ~= 0 then
			
		end
	end
	--@]
end

local message = {}

function message:button(b, p, x, y, s)
	print("btn : ", b, ", pressed : ", p, ", x : ", x, ", y : ", y, ", status : ", s)

	message.cb.button = function (msg_comp, camera)
		if b == "LEFT" then
			
		end
	end
end

function message:motion(x, y, status)
	--print(string.format("motion x = %d, y = %d", x, y))

	local point = {}; point.__index = point
	function point.new(x, y) return setmetatable({x = x, y = y}, point) end
	function point:__add(o) return point.new(self.x + o.x, self.y + o.y) end
	function point:__sub(o) return point.new(self.x - o.x, self.y - o.y) end


	local last_xy = message.xy
	message.last_xy = last_xy

	local xy = point.new(x, y)
	message.xy = xy

	-- message.cb.motion = function (msg_comp, vt, math_stack)
	-- 	assert(math_stack)
	-- 	local states = msg_comp.states

	-- 	if states.buttons.LEFT and last_xy then
	-- 		local delta = xy - last_xy

	-- 		local zdir = vt.direction
		
	-- 		local xdir_id = math_stack(zdir, {0, 1, 0, 0}, "xP")
	-- 		assert(xdir_id ~= nil and xdir_id ~= 0)
	-- 		print("xdir : ", math_stack(xdir_id, "V"))

	-- 		local ydir_id = math_stack(xdir_id, zdir, "xP")
	-- 		assert(ydir_id ~= nil and ydir_id ~= 0)
	-- 		print("ydir : ", math_stack(ydir_id, "V"))

	-- 		--we need to define how many pixel in screen relate to angle
	-- 		local h_angle = delta.x				
	-- 		math_stack(zdir, zdir, {type = "quat", axis = ydir_id, angle = {h_angle}}, "*=")
	-- 		print("after horizontal rotate zdir : ", zdir)

	-- 		local v_angle = delta.y
	-- 		math_stack(zdir, zdir, {type = "quat", axis = xdir_id, angle = {v_angle}}, "*=")
	-- 		print("after vertical rotate zdir : ", zdir)
			
	-- 	end
	-- end
end

function message:keypress(c, p)
	if c == nil then return end

	message.cb.keypress = function(msg_comp, vt, math_stack)
		if p then
			local function rotate_vec(v, axis, angle)
				math_stack(v, v, {type = "quat", axis = axis, angle = {angle}}, "*=")
			end

			local function generate_basic_axis(zdir, up)
				up = up or {0, 1, 0, 0}

				local xdir = math_stack(zdir, up, "xP")
				local ydir = math_stack(xdir, zdir, "xP")

				return xdir, ydir
			end

			local move_step = 1
			local zdir = vt.direction
			local eye = vt.eye

			-- if c == "q" or c == "Q" then				
			-- 	local xdir, ydir = generate_basic_axis(zdir)
			-- 	rotate_vec(zdir, ydir, 60)

			-- 	print("ydir : ", math_stack(ydir, "V"), ", zdir : ", zdir)
			-- elseif c == "e" or c == "E" then
			-- 	local xdir, ydir = generate_basic_axis(zdir)
			-- 	rotate_vec(zdir, xdir, -30)
			-- 	print("ydir : ", math_stack(ydir, "V"), ", zdir : ", zdir)
			-- else
			
			if c == "a" or c == "A" then
				local xdir = generate_basic_axis(zdir)
				math_stack(eye, eye, xdir, {move_step}, "*+=")				
			elseif c == "d" or c == "D" then
				local xdir = generate_basic_axis(zdir)		
				math_stack(eye, eye, xdir, {-move_step}, "*+=")								
			elseif c == "w" or c == "W" then
				local _, ydir = generate_basic_axis(zdir)
				math_stack(eye, eye, ydir, {move_step}, "*+=")
			elseif c == "s" or c == "S" then
				local _, ydir = generate_basic_axis(zdir)
				math_stack(eye, eye, ydir, {-move_step}, "*+=")
			end

			print(eye)
		end
	end
end

--[@
local camera_controller_system = ecs.system "camera_controller"
camera_controller_system.singleton "math_stack"
camera_controller_system.singleton "message_component"

camera_controller_system.depend "iup_message"

function camera_controller_system:init()
	self.message_component.msg_observers:add(message)
	message.cb = {}
end

function camera_controller_system:update()
	ru.for_each_comp(world, {"view_transform", "frustum"},
	function (entity)
		local vt = entity.view_transform		
		for name, cb in pairs(message.cb) do
			cb(self.message_component, vt, self.math_stack)
		end
		
	end)

	message.cb = {}
end
--@]