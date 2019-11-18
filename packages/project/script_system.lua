local ecs = ...
local world = ecs.world

local script_system = ecs.system "script_system"
local callback = nil

function script_system:init()
    callback = world.args.callback
    if callback.init then
        callback.init(ecs,world)
    end
end

function script_system:data_changed()
    if callback.data_changed then
        callback.data_changed(ecs,world)
    end
end

function script_system:asset_loaded()
    if callback.asset_loaded then
        callback.asset_loaded(ecs,world)
    end
end

function script_system:before_update()
    if callback.before_update then
        callback.before_update(ecs,world)
    end
end

function script_system:update()
    if callback.update then
        callback.update(ecs,world)
    end
end

function script_system:after_update()
    if callback.after_update then
        callback.after_update(ecs,world)
    end
end

function script_system:delete()
    if callback.delete then
        callback.delete(ecs,world)
    end
end

function script_system:end_frame()
    if callback.end_frame then
        callback.end_frame(ecs,world)
    end
end

function script_system:on_gui()
    if callback.on_gui then
        callback.on_gui(ecs,world)
    end
end