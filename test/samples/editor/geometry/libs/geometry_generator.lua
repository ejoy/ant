local ecs = ...
local world = ecs.world

local math = import_package "ant.math"
local ms = math.stack

local geometry_drawer = import_package "ant.geometry".drawer

local generator = ecs.system "geometry_generator"
generator.singleton "debug_object"

function generator:init()
	local dbobj = self.debug_object
	
	local desc = dbobj.renderobjs.wireframe.desc
	geometry_drawer.draw_sphere({center={0, 0, 0}, radius=1, tessellation=4}, 0xffffff00, nil, desc)

	-- local transform = ms({type="srt", t={5, 0, 0}}, "P")
	-- geometry_drawer.draw_cone({height=1, radius=0.5, slices=5}, 0xffff0000, transform, desc)

	local camera_entity = world:first_entity("main_queue")	
	
	ms(camera_entity.transform.r, {0, 30, 0}, "=")
end