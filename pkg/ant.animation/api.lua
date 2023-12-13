local ecs = ...
local world = ecs.world
local w = world.w

local m = {}

function m.play(e, name, ratio)
    local status = e.animation.status[name]
    if status.ratio ~= ratio then
        w:extend(e, "animation_changed?out")
        e.animation_changed = true
        status.ratio = ratio
    end
end

return m
