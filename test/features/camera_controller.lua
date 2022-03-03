local ecs = ...
local world = ecs.world
local w = world.w

local rhwi      = import_package "ant.hwi"

local icamera = ecs.import.interface "ant.camera|icamera"

local icc = ecs.interface "icamera_controller"

local controller = {}
function icc.attach(camera_ref)
	controller.camera_ref = camera_ref
end

function icc.camera()
	return controller.camera_ref
end

local cc_sys = ecs.system "camera_controller_system"

local iom = ecs.import.interface "ant.objcontroller|iobj_motion"
local mouse_events = {
	world:sub {"mouse", "LEFT"},
	world:sub {"mouse", "RIGHT"}
}

local kMouseSpeed <const> = 0.5
local mouse_lastx, mouse_lasty
local dpi_x, dpi_y

local eventKeyboard = world:sub {"keyboard"}
local kKeyboardSpeed <const> = 0.5

function cc_sys:post_init()
	dpi_x, dpi_y = rhwi.dpi()
end

local function can_rotate(camera)
	local lt = camera.lock_target
	return lt and lt.type ~= "rotate" or true
end

local function can_move(camera)
	local lock_target = camera.lock_target
	return lock_target and lock_target.type ~= "move" or true
end

local mw_mb = world:sub{"mouse_wheel"}

local function can_orthoview_scale(camera_ref)
	local f = icamera.get_frustum(camera_ref)
	return f.ortho
end

local function scale_orthoview(camera_ref, delta)
	local scale_speed = 0.25
	local f = icamera.get_frustum(camera_ref)
	local d = delta * scale_speed
	f.l = f.l - d
	f.r = f.r + d
	f.b = f.b - d
	f.t = f.t + d

	icamera.set_frustum(camera_ref, f)
end

function cc_sys:init_world()
	for e in w:select "main_queue camera_ref:in" do
        icc.attach(e.camera_ref)
    end
end

function cc_sys:data_changed()
	for _, e in ipairs(mouse_events) do
		local ce = world:entity(icc.camera())
		if can_rotate(ce.camera) then
			for _,_,state,x,y in e:unpack() do
				if state == "MOVE" and mouse_lastx then
					local ux = (x - mouse_lastx) / dpi_x * kMouseSpeed
					local uy = (y - mouse_lasty) / dpi_y * kMouseSpeed
					iom.rotate_forward_vector(ce, uy, ux)
				end
				mouse_lastx, mouse_lasty = x, y
			end
		end
	end

	for _, delta in mw_mb:unpack() do
		local ce = world:entity(icc.camera())
		if can_orthoview_scale(ce) then
			scale_orthoview(ce, delta)
		end
	end

	for _,code,press in eventKeyboard:unpack() do
		local ce = world:entity(icc.camera())
		local keyboard_delta = {0 , 0, 0}
		if can_move(ce.camera) then
			local delta = (press>0) and kKeyboardSpeed or 0
			if code == "A" then
				keyboard_delta[1] = keyboard_delta[1] - delta
			elseif code == "D" then
				keyboard_delta[1] = keyboard_delta[1] + delta
			elseif code == "Q" then
				keyboard_delta[2] = keyboard_delta[2] - delta
			elseif code == "E" then
				keyboard_delta[2] = keyboard_delta[2] + delta
			elseif code == "W" then
				keyboard_delta[3] = keyboard_delta[3] + delta
			elseif code == "S" then
				keyboard_delta[3] = keyboard_delta[3] - delta
			end
		end
		if keyboard_delta[1] ~= 0 or keyboard_delta[2] ~= 0 or keyboard_delta[3] ~= 0 then
			iom.move(ce, keyboard_delta)
		end
	end
end
