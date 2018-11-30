local ecs = ...
local world = ecs.world

ecs.import "render.camera.camera_component"
ecs.import "render.entity_rendering_system"

ecs.import "libs.debug_drawing"

ecs.import "editor.ecs.general_editor_entities"
ecs.import "editor.ecs.camera_controller"
local ms = require "math.stack"

local geometry_drawer = require "editor.ecs.render.geometry_drawer"

local generator = ecs.system "geometry_generator"
generator.singleton "debug_object"

function generator:init()
	local dbobj = self.debug_object
	
	local desc = dbobj.renderobjs.wireframe.desc
	geometry_drawer.draw_sphere({center={0, 0, 0}, radius=1, tessellation=4}, 0xffffff00, nil, desc)

	-- local transform = ms({type="srt", t={5, 0, 0}}, "P")
	-- geometry_drawer.draw_cone({height=1, radius=0.5, slices=5}, 0xffff0000, transform, desc)

	local camera = world:first_entity("main_camera")	
	ms(camera.rotation, {0, 30, 0}, "=")
end