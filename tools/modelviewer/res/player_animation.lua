local m = ...

local move = m.move
move.move_speed = 200
function move:execute()
    if self.move_speed > 400 then
        return "running_fast"
    elseif self.move_speed > 200 then
        return "running"
    else
        return "walking"
    end
end

local attack = m.attack
function attack:execute()
    return "punching"
end
