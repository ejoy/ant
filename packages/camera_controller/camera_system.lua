local ecs = ...
local world = ecs.world

local renderpkg = import_package "ant.render"
local default_comp=renderpkg.default

local mathpkg = import_package "ant.math"
local mc = mathpkg.constant
local ms = mathpkg.stack

-- TODO: will move to another stage, this lock can do with any entity with transform component
local camerasys = ecs.system "camera_system"
function camerasys:lock_target()
    for _, eid in world:each "camera" do
        local camera = world[eid].camera
        local lock_target = camera.lock_target
        if lock_target then
            local locktype = lock_target.type
            if locktype == "move" then
                local targetentity = world[lock_target.target]
                local transform = targetentity.transform
                ms(camera.eyepos, transform.t, lock_target.offset, "+=")
            elseif locktype == "rotate" then
                local targetentity = world[lock_target.target]
                local transform = targetentity.transform

                local eyepos = camera.eyepos
                local targetpos = transform.t
                ms(camera.viewdir, targetpos, eyepos, "-n=")
            else
                error(string.format("not support locktype:%s", locktype))
            end
        end
    end
end