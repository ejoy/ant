local ecs = ...
local world = ecs.world

ecs.import "render.entity_rendering_system"

local generator = ecs.system "geometry_generator"

local drawelem = require "test.samples.geometry.draw_geo"
drawelem.singleton "math_stack"
drawelem.singleton "debug_object"

function generator:init()
	local dbobj = self.debug_object
	local wireframedesc = dbobj.renderobjs.wireframe
	drawelem.draw_sphere({center={0, 0, 0}, radius=1}, 0xffffff00, nil, self.math_stack, wireframedesc)
	
end

function generator:update()
	print("generator")
end