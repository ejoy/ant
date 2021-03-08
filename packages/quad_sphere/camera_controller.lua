local ecs = ...
local world = ecs.world

local math3d = require "math3d"
local mathpkg = import_package "ant.math"
local mc = mathpkg.constant

local rhwi = import_package "ant.render".hwi

local iqs = world:interface "ant.quad_sphere|iquad_sphere"
local iom = world:interface "ant.objcontroller|obj_motion"
local icamera = world:interface "ant.camera|camera"
local _DEBUG<const> = false

local cct = ecs.transform "camera_controller_transform"
function cct.process_entity(e)
    -- targetpos and localpos should be element of camera_controller component, and put it in _camera_controller component
    e._camera_controller = {
        targetpos = math3d.ref(mc.ZERO_PT),
        localpos = math3d.ref(math3d.vector(0, 10, 0, 1)),
        forward = math3d.ref(mc.ZAXIS),
    }
end

local icc = ecs.interface "icamera_controller"

local cceid
function icc.create(cameraeid, qseid)
    if cceid then
        error("can not could more than one time")
    end

    cceid = world:create_entity{
        policy={
            "ant.quad_sphere|camera_controller",
            "ant.general|name",
        },
        data = {
            camera_controller = {},
            name = "quad_sphere_camera_controller",
        }
    }
    icc.attach(cameraeid, qseid)
    return cceid
end


local function check_cc()
    if cceid == nil then
        error("invalid camera contronller eid")
    end

    local cc = world[cceid]._camera_controller
    if cc.qseid == nil then
        error("need attach a quad_sphere")
    end

    if cc.camera_eid == nil then
        error("need attach camera")
    end

    return cc
end

function icc.camera()
    return check_cc().camera_eid
end

function icc.quad_sphere()
    return check_cc().qseid
end

function icc.attach(ceid, qseid)
    local cc = world[cceid]._camera_controller
    cc.camera_eid, cc.qseid = ceid, qseid
end

function icc.is_active()
    local e = world[cceid]
    local ceid = e._camera_controller.camera_eid
    if ceid and world[ceid] then
        return icamera.controller(ceid) == cceid
    end
end

function icc.get()
    return cceid
end

local function updateview(cc)
    local targetpos, forward, localpos = cc.targetpos, cc.forward, cc.localpos
    local n = math3d.normalize(targetpos)
    local r = math3d.cross(n, forward)
    local m = math3d.set_columns(mc.IDENTITY_MAT, r, n, forward, targetpos)
    
    local eyepos = math3d.transform(m, localpos, 1)
    local viewdir = math3d.normalize(math3d.sub(targetpos, eyepos))
    local rightdir = math3d.cross(forward, viewdir)
    local updir = math3d.cross(rightdir, viewdir)
    iom.lookto(cc.camera_eid, eyepos, viewdir, updir)
end

local twopi<const> = math.pi * 2
local function calc_rotation(targetpos, radian_ratio)
    local r = radian_ratio * twopi
    local n = math3d.normalize(targetpos)
    return math3d.quaternion{axis=n, r=r}
end

local function calc_forward(targetpos, forward, radian_ratio)
    local q = calc_rotation(targetpos, radian_ratio)
    return math3d.transform(q, forward, 0)
end

local function rotate_local_forward(radian_ratio)
    --TODO: there is a more fast version for rotate vector around YAXIS
    local r = radian_ratio * twopi
    local q = math3d.quaternion{axis=mc.YAXIS, r=r}
    return math3d.transform(q, mc.ZAXIS, 0)
end

local function rotate_forward(targetpos, radian_ratio)
    local tm = iqs.tangent_matrix(targetpos)
    local f = rotate_local_forward(radian_ratio)
    return math3d.normalize(math3d.transform(tm, f, 0))
end

function icc.set_view(targetpos, localpos, radian_ratio)
    local cc = check_cc()

    cc.targetpos.v = targetpos
    cc.localpos.v = localpos

    cc.forward.v = rotate_forward(cc.targetpos, radian_ratio)
    assert(0 == math3d.dot(cc.forward, targetpos))
    updateview(cc)

    local trunkid = iqs.trunk_coord(cc.qseid, cc.targetpos)
    iqs.set_trunkid(cc.qseid, trunkid)
end

function icc.set_forward(radian_ratio)
    local cc = check_cc()

    cc.forward.v = rotate_forward(cc.targetpos, radian_ratio)
end

function icc.forward()
    return check_cc().forward
end

function icc.move(df, dr)
    local cc = check_cc()

    local t, f = cc.targetpos, cc.forward
    t.v, f.v = iqs.move(cc.qseid, t, f, df, dr)
    updateview(cc)
end

function icc.rotate(radian_ratio)
    local cc = check_cc()
    cc.forward.v = calc_forward(cc.targetpos, cc.forward, radian_ratio)
end

local cc = ecs.system "camera_controller"

local mouse_events = {
	world:sub {"mouse", "LEFT"},
	world:sub {"mouse", "RIGHT"}
}
local mw_mb = world:sub{"mouse_wheel"}

local move_speed <const> = 0.5
local mouse_lastx, mouse_lasty
local dpi_x, dpi_y

local keyboard_event = world:sub {"keyboard"}
local keyboard_speed <const> = 0.1

function cc:post_init()
	dpi_x, dpi_y = rhwi.dpi()
end

-- local function can_rotate(cameraeid)
-- 	local lock_target = world[cameraeid].lock_target
-- 	return lock_target and lock_target.type ~= "rotate" or true
-- end

-- local function can_move(cameraeid)
-- 	local lock_target = world[cameraeid].lock_target
-- 	return lock_target and lock_target.type ~= "move" or true
-- end

function cc:data_changed()
    if not icc.is_active() then
        return 
    end
	-- if can_rotate() then
    --     local cameraeid = icc.camera()
	-- 	for _, e in ipairs(mouse_events) do
	-- 		for _,_,state,x,y in e:unpack() do
	-- 			if state == "MOVE" and mouse_lastx then
	-- 				local ux = (x - mouse_lastx) / dpi_x * move_speed
	-- 				local uy = (y - mouse_lasty) / dpi_y * move_speed
	-- 				iom.rotate_forward_vector(cameraeid, uy, ux)
	-- 			end
	-- 			mouse_lastx, mouse_lasty = x, y
	-- 		end
	-- 	end
	-- end

	--if can_move() then
		--local keyboard_delta = {0 , 0, 0}
        local df, dr = 0, 0
		for _,code,press in keyboard_event:unpack() do
			local delta = (press>0) and keyboard_speed or 0
			if code == "A" then
				--keyboard_delta[1] = keyboard_delta[1] - delta
                dr = dr - delta
			elseif code == "D" then
				--keyboard_delta[1] = keyboard_delta[1] + delta
                dr = dr + delta
			-- elseif code == "Q" then
			-- 	keyboard_delta[2] = keyboard_delta[2] - delta
			-- elseif code == "E" then
			-- 	keyboard_delta[2] = keyboard_delta[2] + delta
			elseif code == "W" then
			-- keyboard_delta[3] = keyboard_delta[3] + delta
                df = df - delta
			elseif code == "S" then
				--keyboard_delta[3] = keyboard_delta[3] - delta
                df = df + delta
			end
		end
		--if keyboard_delta[1] ~= 0 or keyboard_delta[2] ~= 0 or keyboard_delta[3] ~= 0 then
        if df ~= 0 or dr ~= 0 then
            icc.move(df, dr)
		end
	--end
end
