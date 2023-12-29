local ecs	= ...
local world = ecs.world
local w 	= world.w
local math3d = require "math3d"

local ientity 	= ecs.require "ant.render|components.entity"
local imesh		= ecs.require "ant.asset|mesh"
local imaterial = ecs.require "ant.asset|material"
local iom		= ecs.require "ant.objcontroller|obj_motion"
local common 	= ecs.require "common"

local util		= ecs.require "util"

local PC		= util.proxy_creator()

local function create_instance(pfile, s, r, t)
	s = s or {0.1, 0.1, 0.1}
	return util.create_instance(
        pfile,
		function (p)
			local ee<close> = world:entity(p.tag["*"][1])
			iom.set_scale(ee, s)
	
			if r then
				iom.set_rotation(ee, r)
			end
	
			if t then
				iom.set_position(ee, t)
			end

			PC:add_prefab(p)
		end)
end

local st_sys	= common.test_system "shadow_test_system"
function st_sys:init()
	util.create_instance("/pkg/ant.resources.binary/meshes/DamagedHelmet.glb|mesh.prefab", function (e)
        local root<close> = world:entity(e.tag['*'][1])
        iom.set_position(root, math3d.vector(3, 1, 0))
		PC:add_prefab(e)
    end)

	create_instance("/pkg/ant.resources.binary/meshes/base/cube.glb|mesh.prefab", {10, 0.1, 10}, nil, {10, 0, 0, 1})
	local root = PC:create_entity {
		policy = {
			"ant.scene|scene_object",
		},
		data = {
			scene =  {t={10, 0, 0}},
		}
	}

	PC:create_entity{
		policy = {
			"ant.render|simplerender",
		},
		data = {
			scene 		= {
                t = {0, 0, 0, 1},
				s = {50, 1, 50, 0},
				parent = root,
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

function st_sys:entity_init()
	for e in w:select "INIT make_shadow light:in scene:in eid:in" do
		PC:add_entity(ientity.create_arrow_entity(0.3, {1, 1, 1, 1}, "/pkg/ant.resources/materials/meshcolor.material", {parent=e.eid}))
	end
end

function st_sys:exit()
	PC:clear()
end
