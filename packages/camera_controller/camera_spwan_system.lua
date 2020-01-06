local ecs = ...
local world = ecs.world

local camera_spawn = ecs.system "camera_spawn_system"
local sc_mb = world:sub {"spawn_camera"}

local renderpkg = import_package "ant.render"
local camerautil= renderpkg.camera
local default_comp=renderpkg.default

local mathpkg = import_package "ant.math"
local mc = mathpkg.constant

local default_frustum = default_comp.frustum()

function camera_spawn:init()
    camerautil.create_camera_mgr_entity(world)
end

function camera_spawn:spawn_camera()
    local mq = world:first_entity "main_queue"
    for _, name, info in sc_mb:unpack() do
        camerautil.bind_camera(world, name, {
            type    = info.type     or "",
            eyepos  = info.eyepos   or mc.ZERO_PT,
            viewdir = info.viewdir  or mc.Z_AXIS,
            updir   = info.updir    or mc.Y_AXIS,
            frustum = info.frustum  or default_frustum,
        })
        if mq.camera_tag == "" then
            mq.camera_tag = name
        end

        world:pub {"camera_spawned", name}
    end
end


local bind_camera_mb = world:sub {"bind_camera"}

local camera_bind = ecs.system "camera_bind_system"
camera_bind.require_system "camera_spawn_system"

function camera_bind:bind_camera()
    for _, cameraname, dest in bind_camera_mb:unpack() do
        if dest == "main_queue" then
            local mq = world:first_entity "main_queue"
            mq.camera_tag = cameraname
        elseif dest == nil or dest == "editor.image" then
            assert("need implement")
        end
    end
end