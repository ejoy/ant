local ecs = ...
local world = ecs.world
local w = world.w

local ianimation = ecs.require "ant.animation|animation"

local iani_loader = {}

function iani_loader.load(eid, filename)
	local e <close> = world:entity(eid, "animation:in animation_changed?out")
	ianimation.create(filename .. "/animations/animation.ozz", e.animation)
	e.animation_changed = true
end

return iani_loader

