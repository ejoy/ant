local ecs = ...
local world = ecs.world
local w = world.w

local m = ecs.system 'init_system'
local irq = ecs.import.interface "ant.render|irenderqueue"
local ientity = ecs.import.interface "ant.render|ientity"
local imesh = ecs.import.interface "ant.asset|imesh"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local math3d = require "math3d"
local function create_plane()
    ecs.create_entity{
		policy = {
			"ant.render|simplerender",
			"ant.general|name",
		},
		data = {
			scene = {
                t = {0, 0, 0, 1}, s = {50, 1, 50, 0}
            },
			material 	= "/pkg/ant.resources/materials/mesh_shadow.material",
			filter_state= "main_view",
			name 		= "test_shadow_plane",
			simplemesh 	= imesh.init_mesh(ientity.plane_mesh()),
            debug_mesh_bounding = true,
			on_ready = function (e)
				w:sync("render_object:in", e)
				imaterial.set_property(e, "u_basecolor_factor", math3d.vector(0.8, 0.8, 0.8, 1))
			end,
		}
    }
end

function m:init_world()
    ientity.create_procedural_sky()
    create_plane()
    irq.set_view_clear_color("main_queue", 0xff0000ff)
    ecs.create_instance "/res/scenes.prefab"
end
