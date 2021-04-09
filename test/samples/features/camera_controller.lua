local ecs = ...
local world = ecs.world

local rhwi      = import_package "ant.hwi"

local icamera = world:interface "ant.camera|camera"

local cct = ecs.transform "camera_controller"
function cct.process_entity(e)
	e._camera_controller = {}
end

local icc = ecs.interface "icamera_controller"

local cceid
function icc.create(ceid)
	if cceid then
		error("could not create more than two time")
	end

	cceid = world:create_entity{
		policy = {
			"ant.test.features|camera_controller",
			"ant.general|name",
		},
		data = {
			camera_controller = {},
			name = "test",
			test_feature_camera_controller = true,
		}
	}

	icc.camera(ceid)
	return cceid
end

function icc.attach(ceid)
	local cc = world[cceid]._camera_controller
	local old_cameraeid = cc.camera_eid
	cc.camera_eid = ceid
	world:pub{"camera_controller_changed", "camera", ceid, old_cameraeid}
	icamera.controller(ceid, cceid)
end

function icc.get()
	return cceid
end

function icc.camera()
	return world[cceid]._camera_controller.camera_eid
end

function icc.is_active()
	local ceid = world[cceid]._camera_controller.camera_eid
	if ceid and world[ceid] then
		return icamera.controller(ceid) == cceid
	end
end

local cc_sys = ecs.system "camera_controller_system"

local iom = world:interface "ant.objcontroller|obj_motion"
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

local function can_rotate(eid)
	local lock_target = world[eid].lock_target
	return lock_target and lock_target.type ~= "rotate" or true
end

local function can_move(eid)
	local lock_target = world[eid].lock_target
	return lock_target and lock_target.type ~= "move" or true
end

local svs_mb = world:sub{"splitviews", "selected"}
local mw_mb = world:sub{"mouse_wheel"}

local function can_orthoview_scale(cameraeid)
	local f = icamera.get_frustum(cameraeid)
	return f.ortho
end

local function scale_orthoview(cameraeid, delta)
	local scale_speed = 0.25
	local f = icamera.get_frustum(cameraeid)
	local d = delta * scale_speed
	f.l = f.l - d
	f.r = f.r + d
	f.b = f.b - d
	f.t = f.t + d

	icamera.set_frustum(cameraeid, f)
end

function cc_sys:data_changed()
	--TODO: need another ortho view camera_controller
	if not icc.is_active() then
		return
	end

	local cameraeid
	for _, t, eid in svs_mb:unpack() do
		cameraeid = world[eid].camera_eid
	end

	cameraeid = cameraeid or icc.camera()

	if can_rotate(cameraeid) then
		for _, e in ipairs(mouse_events) do
			for _,_,state,x,y in e:unpack() do
				if state == "MOVE" and mouse_lastx then
					local ux = (x - mouse_lastx) / dpi_x * kMouseSpeed
					local uy = (y - mouse_lasty) / dpi_y * kMouseSpeed
					iom.rotate_forward_vector(cameraeid, uy, ux)
				end
				mouse_lastx, mouse_lasty = x, y
			end
		end
	end

	if can_orthoview_scale(cameraeid) then
		for _, delta in mw_mb:unpack() do
			scale_orthoview(cameraeid, delta)
		end
	end

	if can_move(cameraeid) then
		local keyboard_delta = {0 , 0, 0}
		for _,code,press in eventKeyboard:unpack() do
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
			iom.move(cameraeid, keyboard_delta)
		end
	end
end
