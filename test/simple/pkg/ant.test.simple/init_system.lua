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
			visible_state= "main_view",
			name 		= "test_shadow_plane",
			simplemesh 	= imesh.init_mesh(ientity.plane_mesh()),
            debug_mesh_bounding = true,
			on_ready = function (e)
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

local EventGesture = world:sub { "gesture" }

local function stringify(str, n, t)
	for k, v in pairs(t) do
		if type(v) == "table" then
			str[#str+1] = string.rep('  ', n)..k..': '
			stringify(str, n+1, v)
		else
			str[#str+1] = string.rep('  ', n)..k..': '..v
		end
	end
end

function m:data_changed()
	for _, what, e in EventGesture:unpack() do
		local str = {'',what}
		stringify(str, 1, e)
		print(table.concat(str, "\n"))
	end
end
