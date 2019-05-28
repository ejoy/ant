-- move it to common math utils
local function to_radian(angles)
    local function radian(angle)
        return (math.pi / 180) * angle
    end

    local radians = {}
    for i=1, #angles do
        radians[i] = radian(angles[i])
    end
    return radians
end

local function to_angle(rad)
    local function angle(rad)
        return (180/math.pi)*rad
    end 
    local angles = {}
    for i=1,#rad do 
        angles[i] = angle(rad[i])
    end 
    return angles
end 

return  {
    to_radian = to_radian,
    to_angle = to_angle,
}
