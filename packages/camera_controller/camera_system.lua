local ecs = ...
local world = ecs.world

local camerasys = ecs.system "camera_system"
local sc_mb = world:sub {"spawn_camera"}

local renderpkg = import_package "ant.render"
local camerautil= renderpkg.camera
local default_comp=renderpkg.default

local mathpkg = import_package "ant.math"
local mc = mathpkg.constant
local ms = mathpkg.stack

local default_frustum = default_comp.frustum()

function camerasys:init()
    camerautil.create_camera_mgr_entity(world)
end

function camerasys:spawn_camera()
    local mq = world:first_entity "main_queue"
    for _, name, info in sc_mb:unpack() do
        camerautil.bind_camera(world, name, {
            type    = info.type     or "",
            eyepos  = info.eyepos   or mc.T_ZERO_PT,
            viewdir = info.viewdir  or mc.T_ZAXIS,
            updir   = info.updir    or mc.T_NXAXIS,
            frustum = info.frustum  or default_frustum,
        })
        if mq.camera_tag == "" then
            mq.camera_tag = name
        end

        world:pub {"camera_spawned", name}
    end
end


local bind_camera_mb = world:sub {"bind_camera"}

function camerasys:bind_camera()
    for _, cameraname, dest in bind_camera_mb:unpack() do
        if dest == "main_queue" then
            local mq = world:first_entity "main_queue"
            mq.camera_tag = cameraname
        elseif dest == nil or dest == "editor.image" then
            assert("need implement")
        end
    end
end

local motion_camera_mb = world:sub {"motion_camera"}

function camerasys:motion_camera()
    for _, motiontype, cameraname, value in motion_camera_mb:unpack() do
        local camera = camerautil.get_camera(cameraname)

        if motiontype == "target" then
            local lock_target = camera.lock_target
            if lock_target == nil then
                lock_target = {}
                camera.lock_target = lock_target
            end

            lock_target.type = value.type
            local eid = value.eid
            if world[eid].transform == nil then
                error(string.format("camera lock target entity must have transform component"));
            end
            lock_target.target = value.eid
            local offset = value.offset or mc.ZERO
            lock_target.offset = ms:ref "vector"(offset)
        elseif motiontype == "move" then
            ms(camera.eyepos, value, "=")
        elseif motiontype == "rotate" then
            ms(camera.viewdir, value, "dn=")
        end
    end
end

function camerasys:camera_lock_target()
    for _, eid in world:each "camera_tag" do
        local camera = camerautil.get_camera(world[eid].camera_tag)
        local lock_target = camera.lock_target
        local locktype = lock_target.type
        if locktype == "move" then
            local targetentity = world[lock_target.eid]
            local transform = targetentity.transform
            ms(camera.eyepos, transform.t, lock_target.offset, "+=")
        elseif locktype == "rotate" then
            local targetentity = world[lock_target.eid]
            local transform = targetentity.transform

            local eyepos = camera.eyepos
            local targetpos = transform.t
            ms(camera.viewdir, targetpos, eyepos, "-n=")
        else
            error(string.format("not support locktype:%s", locktype))
        end
    end
end