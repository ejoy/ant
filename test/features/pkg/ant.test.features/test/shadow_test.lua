local ecs	= ...
local world = ecs.world
local w 	= world.w
local math3d = require "math3d"

local ientity 	= ecs.require "ant.render|components.entity"
local imesh		= ecs.require "ant.asset|mesh"
local imaterial = ecs.require "ant.asset|material"
local iom		= ecs.require "ant.objcontroller|obj_motion"
local ipt		= ecs.require "ant.landform|plane_terrain"
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

local function multi_entities()
	local rn = 12
	for i=1, rn * 24 do
		local xidx, zidx = (i-1)%rn, (i-1)//rn
		local pos = math3d.vector(xidx * 80 - 80, 10, zidx * 80 - 80)
		util.create_instance("/pkg/ant.resources.binary/meshes/DamagedHelmet.glb|mesh.prefab", function (e)
			local root<close> = world:entity(e.tag['*'][1])
			iom.set_scale(root, 10)
			iom.set_position(root, pos)
			PC:add_prefab(e)
		end)
	end

	local cs = 16 * 10

	local positions = {}
	local size = 32
	local offset = (size // 2) * cs
	for j=1, size do
		for i=1, size do
			positions[#positions+1] = {x=(i-1)*cs-offset, y=(j-1)*cs-offset}
		end
	end

	local groups = {
		[0] = positions,
	}

	ipt.create_plane_terrain(groups, "opacity", cs, "/pkg/ant.test.features/assets/terrain/plane_terrain.material")
end

local function simple_entities()
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

	util.create_instance("/pkg/ant.resources.binary/meshes/DamagedHelmet.glb|mesh.prefab", function (e)
		local root<close> = world:entity(e.tag['*'][1])
		iom.set_scale(root, 10)
		iom.set_position(root, math3d.vector(5.0, 0.0, 0.0, 1.0))
		PC:add_prefab(e)
	end)

end

local st_sys	= common.test_system "shadow"
function st_sys:init()
	simple_entities()
end

function st_sys:entity_init()
	for e in w:select "INIT make_shadow light:in scene:in eid:in" do
		PC:add_entity(ientity.create_arrow_entity(0.3, {1, 1, 1, 1}, "/pkg/ant.resources/materials/meshcolor.material", {parent=e.eid}))
	end
end

function st_sys:exit()
	PC:clear()
	ipt.clear_plane_terrain()
end
