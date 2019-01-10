
local utilmath = {}

-- tested
function utilmath.direction(dir,ha,ca)
    local h = math.rad(ha)
    local c = math.rad(-ca)     -- inner transfer
    -- table.insert(dir, math.cos(c) * math.sin(h) )
    -- table.insert(dir, math.sin(c) )
    -- table.insert(dir, math.cos(c) * math.cos(h))
    dir[1] = math.cos(c) * math.sin(h)
    dir[2] = math.sin(c)
    dir[3] = math.cos(c) * math.cos(h)
end 

function utilmath.dir(ha,ca)
    local h = math.rad(ha)
    local c = math.rad(-ca)     
    local dir = { 0,0,0 }
    dir[1] = math.cos(c) * math.sin(h)
    dir[2] = math.sin(c)
    dir[3] = math.cos(c) * math.cos(h)
    return dir 
end 

function utilmath.side(ha,ca)
    local h = math.rad(ha)
    local c = math.rad(-ca)
    local right = {0,0,0}
    right[1] = math.sin( h -math.pi*0.5 )
    right[2] = 0
    right[3] = math.cos( h -math.pi*0.5 )
    return right 
end 

return utilmath 
