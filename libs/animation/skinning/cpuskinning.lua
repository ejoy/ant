local ecs = ...
local world = ecs.world

local animodule = require "hierarchy.animation"

local cpuskinning = ecs.system "cpuskinning"

cpuskinning.singleton "math_stack"

function cpuskinning:init()

end

-- function cpuskinning:update()
-- 	for _, eid in world:each("animation") do
-- 		local e = world[eid]
		
-- 		local meshcomp = assert(e.mesh)		
-- 		local ske = e.skeleton
-- 		if ske then
-- 			local config = {
-- 				influences_count = 5,
-- 				vertex_count = ,
-- 			}
-- 			animodule.cpuskinning()
-- 		end
-- 	end
-- end