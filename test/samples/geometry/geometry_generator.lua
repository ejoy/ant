local ecs = ...
local world = ecs.world

ecs.import "render.math3d.math_component"
ecs.import "render.camera.camera_component"
ecs.import "render.entity_rendering_system"

ecs.import "test.samples.geometry.debug_drawing"


local geometry_drawer = require "test.samples.geometry.draw_geo"

local generator = ecs.system "geometry_generator"
generator.singleton "math_stack"
generator.singleton "debug_object"

function generator:init()
	local dbobj = self.debug_object
	local ms = self.math_stack
	local wireframedesc = dbobj.renderobjs.wireframe
	geometry_drawer.draw_sphere({center={0, 0, 0}, radius=1}, 0xffffff00, nil, self.math_stack, wireframedesc)
	

	local transform = ms({type="srt", t={5, 0, 0}}, "P")
	geometry_drawer.draw_cone({height=1, radius=0.5}, 0xffff0000, transform, ms, wireframedesc)
end