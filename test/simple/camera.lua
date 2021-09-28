local ecs = ...
local world = ecs.world

local object = ecs.create_instance "/res/camera.prefab"
local camera = object.tag.camera[1]

function object:on_init()
end

function object:on_ready()
    world:call(camera, "get_position")
end

function object:on_message(msg)
    --print(object, msg)
end

function object:on_update()
    --print "update"
end

return world:create_object(object)
