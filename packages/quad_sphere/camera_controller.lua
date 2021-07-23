local ecs = ...
local world = ecs.world

local math3d = require "math3d"
local mathpkg = import_package "ant.math"
local mc = mathpkg.constant

local rhwi = import_package "ant.hwi"

local iqs = world:interface "ant.quad_sphere|iquad_sphere"
local iom = world:interface "ant.objcontroller|obj_motion"
local icamera = world:interface "ant.camera|camera"
local _DEBUG<const> = false

local twopi<const> = math.pi * 2
local halfpi<const> = math.pi * 0.5

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
        --TODO
        return true
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

local function rotate_local_forward(radian)
    --TODO: there is a more fast version for rotate vector around YAXIS
    local q = math3d.quaternion{axis=mc.YAXIS, r=radian}
    return math3d.transform(q, mc.ZAXIS, 0)
end

local function rotate_forward(targetpos, radian)
    local tm = iqs.tangent_matrix(targetpos)
    local f = rotate_local_forward(radian)
    return math3d.normalize(math3d.transform(tm, f, 0))
end

function icc.set_view(targetpos, localpos, radian_ratio)
    local cc = check_cc()

    cc.targetpos.v = targetpos
    cc.localpos.v = localpos

    cc.forward_rotate_radian = radian_ratio * twopi
    cc.forward.v = rotate_forward(cc.targetpos, cc.forward_rotate_radian)
    
    assert(0 == math3d.dot(cc.forward, targetpos))
    updateview(cc)
end

function icc.set_forward(radian_ratio)
    local cc = check_cc()
    cc.forward_rotate_radian = radian_ratio * twopi
    cc.forward.v = rotate_forward(cc.targetpos, cc.forward_rotate_radian)
end

function icc.forward()
    return check_cc().forward
end

function icc.move(df, dr)
    local cc = check_cc()

    cc.targetpos.v = iqs.move(cc.qseid, cc.targetpos, cc.forward, df, dr)
    cc.forward.v = rotate_forward(cc.targetpos, cc.forward_rotate_radian)
    updateview(cc)
end

function icc.move_distance(dd)
    local cc = check_cc()
    local lp = cc.localpos
    lp.v = math3d.muladd(dd, lp, lp)
    updateview(cc)
end

function icc.rotate(delta_radian_ratio)
    local cc = check_cc()
    local delta_radian = delta_radian_ratio * twopi
    cc.forward_rotate_radian = cc.forward_rotate_radian + delta_radian
    cc.forward.v = rotate_forward(cc.targetpos, cc.forward_rotate_radian)
end

function icc.rotate_view(du, dr)
    
end

function icc.coord_info()
    local cc = check_cc()
    local trunkid, tx, ty = iqs.trunk_coord(cc.qseid, cc.targetpos)

    local _, nx, ny = iqs.which_face(math3d.tovalue(cc.froward))
    local radian = math.asin(ny)
    radian = nx > 0 and radian or (radian + math.pi)
    assert(radian < twopi)
    return trunkid, tx, ty, radian / twopi
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

function cc:data_changed()
    if not icc.is_active() then
        return 
    end

    local cameraeid = icc.camera()
    for _, e in ipairs(mouse_events) do
        for _,_,state,x,y in e:unpack() do
            if state == "MOVE" and mouse_lastx then
                local ux = (x - mouse_lastx) / dpi_x * move_speed
                local uy = (y - mouse_lasty) / dpi_y * move_speed
                --iom.rotate_forward_vector(cameraeid, uy, ux)
            end
            mouse_lastx, mouse_lasty = x, y
        end
    end

	
    local df, dr = 0, 0
    local dd = 0
    for _,code,press in keyboard_event:unpack() do
        local delta = (press>0) and keyboard_speed or 0
        if code == "A" then
            dr = dr - delta
        elseif code == "D" then
            dr = dr + delta
        elseif code == "W" then
            df = df - delta
        elseif code == "S" then
            df = df + delta
        elseif code == "Q" then
            dd = dd - delta
        elseif code == "E" then
            dd = dd + delta
        end
    end
    if df ~= 0 or dr ~= 0 then
        icc.move(df, dr)
    end

    if dd ~= 0 then
        icc.move_distance(dd)
    end
end

function cc:camera_usage()
    if not icc.is_active() then
        return 
    end

    iqs.update_visible_trunks(icc.quad_sphere(), icc.camera())
end
