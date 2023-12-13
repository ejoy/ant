local ecs = ...
local world = ecs.world
local w = world.w

local m = ecs.system 'init_system'
local irq = ecs.require "ant.render|render_system.renderqueue"
local ientity = ecs.require "ant.render|components.entity"
local imesh = ecs.require "ant.asset|mesh"
local imaterial = ecs.require "ant.asset|material"
local math3d = require "math3d"
local function create_plane()
    world:create_entity{
		policy = {
			"ant.render|simplerender",
		},
		data = {
			scene = {
                t = {0, 0, 0, 1}, s = {50, 1, 50, 0}
            },
			material 	= "/pkg/ant.resources/materials/mesh_shadow.material",
			visible_state= "main_view",
			simplemesh 	= imesh.init_mesh(ientity.plane_mesh()),
            debug_mesh_bounding = true,
			on_ready = function (e)
				imaterial.set_property(e, "u_basecolor_factor", math3d.vector(0.8, 0.8, 0.8, 1))
			end,
		}
    }
end

function m:init_world()
    create_plane()
    irq.set_view_clear_color("main_queue", 0xff0000ff)
    world:create_instance {
		prefab = "/pkg/ant.test.simple/resource/scenes.prefab"
	}
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
