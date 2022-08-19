local ecs = ...
local world = ecs.world
local w = world.w

--[[
    1. use new lighting shader. 
    2. use new ibl. we try to use filament ibl texture to create ibl light, maybe ibl is the key reason
    3. use new tonemapping&bloom. a bake version of tonemapping is use in filament, it's another key reason for light.
]]

local S = ecs.system "init_system"

local MF = "/pkg/ant.test.light/assets/test.material"

function S.init()
    
end

