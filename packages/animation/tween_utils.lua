local M = {}
M.TWEEN_LINEAR = 1
M.TWEEN_CUBIC_IN = 2
M.TWEEN_CUBIC_OUT = 3
M.TWEEN_CUBIC_INOUT = 4
M.TWEEN_BOUNCE_IN = 5
M.TWEEN_BOUNCE_OUT = 6
M.TWEEN_BOUNCE_INOUT = 7

local function bounce_time(time)
    if time < 1 / 2.75 then
        return 7.5625 * time * time
    elseif time < 2 / 2.75 then
        time = time - 1.5 / 2.75
        return 7.5625 * time * time + 0.75
    
    elseif time < 2.5 / 2.75 then
        time = time - 2.25 / 2.75
        return 7.5625 * time * time + 0.9375
    end
    time = time - 2.625 / 2.75
    return 7.5625 * time * time + 0.984375
end

M.tween = {
    function (time) return time end,
    function (time) return time * time * time end,
    function (time)
        time = time - 1
        return (time * time * time + 1)
    end,
    function (time)
        time = time * 2
        if time < 1 then
            return 0.5 * time * time * time
        end
        time = time - 2;
        return 0.5 * (time * time * time + 2)
    end,
    function (time) return 1 - bounce_time(1 - time) end,
    function (time) return bounce_time(time) end,
    function (time)
        local newT = 0
        if time < 0.5 then
            time = time * 2;
            newT = (1 - bounce_time(1 - time)) * 0.5
        else
            newT = bounce_time(time * 2 - 1) * 0.5 + 0.5
        end
        return newT
    end,
}

return M