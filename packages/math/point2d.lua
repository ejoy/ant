local point2d = {}; point2d.__index = point2d

setmetatable(point2d, {__call = function (t, ...)return point2d.new(...) end})

function point2d.new(x, y) 
    return setmetatable({x = x, y = y}, point2d) 
end

function point2d:__add(o) 
    return point2d(self.x + o.x, self.y + o.y) 
end

function point2d:__sub(o) 
    return point2d(self.x - o.x, self.y - o.y) 
end

function point2d:__mul(s) 
    return point2d(self.x*s, self.y*s) 
end

return point2d

