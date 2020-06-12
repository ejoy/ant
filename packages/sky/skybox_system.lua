local ecs = ...
local world = ecs.world

local ie = world:interface "ant.render|entity"

local skybox_sys = ecs.system "skybox_system"

function skybox_sys:init()
    ie.create_skybox()
end