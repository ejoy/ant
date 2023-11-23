local ecs   = ...
local world = ecs.world
local w     = world.w

local setting   = import_package "ant.settings"

local SCENE_RATIO<const> 	= setting:get "framebuffer/scene_ratio" or 1.0
local RATIO<const> 			= setting:get "framebuffer/ratio" 		or 1.0

world.args.framebuffer.ratio 		= RATIO
world.args.framebuffer.scene_ratio 	= SCENE_RATIO
log.info(("framebuffer ratio:%2f, scene:%2f"):format(RATIO, SCENE_RATIO))
