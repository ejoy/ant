local ecs = ...
local world = ecs.world

local script_sys = ecs.system "script_system"
local callback = nil

function script_sys:init()
    callback = world.args.callback
    if callback.init then
        callback.init(ecs,world)
    end
end

function script_sys:data_changed()
    if callback.data_changed then
        callback.data_changed(ecs,world)
    end
end

function script_sys:before_update()
    if callback.before_update then
        callback.before_update(ecs,world)
    end
end

function script_sys:end_frame()
    if callback.end_frame then
        callback.end_frame(ecs,world)
    end
end

function script_sys:on_gui()
    if callback.on_gui then
        callback.on_gui(ecs,world)
    end
end