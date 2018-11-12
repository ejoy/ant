local ecs = ...
local world = ecs.world

ecs.import "render.math3d.math_component"
ecs.import "render.constant_system"
ecs.import "inputmgr.message_system"

ecs.import "render.math3d.math_component"
ecs.import "render.constant_system"
ecs.import "inputmgr.message_system"

-- light entity
ecs.import "serialize.serialize_component"
ecs.import "render.light.light"

-- filter
ecs.import "scene.filter.lighting_filter"
ecs.import "scene.filter.shadow_filter"
ecs.import "scene.filter.transparency_filter"


-- test entity
ecs.import "editor.ecs.editable_hierarchy"

-- enable
ecs.import "serialize.serialize_system"
ecs.import "render.view_system"
ecs.import "render.entity_rendering_system"
ecs.import "scene.hierarchy.hierarchy"
-- ecs.import "scene.cull_system"

local component_util = require "render.components.util"
local lu = require "render.light.util"
local assetmgr = require "asset"

local update_direction_light_sys = ecs.system "direction_light_system"
update_direction_light_sys.singleton "math_stack"

function update_direction_light_sys:update()
    if true then
       return
    end

	local ms = self.math_stack

	local function get_delta_time_op()
		local baselib = require "bgfx.baselib"
		local lasttime = baselib.HP_time("s")
		return function()
			local curtime = baselib.HP_time("s")
			local delta = curtime - lasttime
			lasttime = curtime
			return delta
		end
	end

	local angleXpresecond = 20
	local angleYpresecond = 15

	local deltatime_op = get_delta_time_op()
	for _, eid in world:each("directional_light") do		
		local e = world[eid]

		local delta = deltatime_op() 

		local rot = ms(e.rotation, "T")
		rot[3] = rot[3] + math.sin(delta) * angleXpresecond *0.1
		rot[2] = rot[2] + math.cos(delta) * angleYpresecond *0.1

		ms(e.rotation, rot, "=")
	end
end

local add_entity_sys = ecs.system "add_entities_system"

add_entity_sys.singleton "math_stack"
add_entity_sys.singleton "constant"

add_entity_sys.depend "constant_init_sys"
add_entity_sys.dependby "message_system"


function add_entity_sys:init()
	local ms = self.math_stack

	do
		local leid = lu.create_directional_light_entity(world)
		world:add_component(leid, "position", "mesh", "material", "can_render", "scale", "name")
		local lentity = world[leid]

		local lightcomp = lentity.light.v
		lightcomp.color = {1,1,1,1}
		lightcomp.intensity = 2.0

		ms(lentity.rotation, {45, 145, -45}, "=")
		ms(lentity.position, {200, 200, 200}, "=")
		

		ms(lentity.scale, {1.1, 1.1, 1.1}, "=")

		lentity.name.n = "directional_light"

		-- add tested for ambient 
		local am_eid = lu.create_ambient_light_entity(world)
		local am_entity = world[ am_eid]
		local ambient_comp = am_entity.ambient_light.data
		ambient_comp.mode = "gradient"
		ambient_comp.skycolor = {1,1,1,1}
		ambient_comp.midcolor  = {0.9,0.9,1,1}
		ambient_comp.groundcolor  = {0.50,0.74,0.68,1}
		--ambient_comp.skycolor = {0.8,0.8,0.8,1} --{0.28,0,1,1}
		--ambient_comp.midcolor = {0,1,0,1}
		--ambient_comp.groundcolor = {0,0,1,1}
		--ambient_comp.factor = 0.25
		lentity.name.n = "ambient_light"
		--print("-------ambient entity  "..am_entity.name.n..'  '..am_eid)

		component_util.load_mesh(lentity.mesh,"sphere.mesh")		
		component_util.load_material(lentity.material,{"light_bulb.material"})

		lentity.can_render.visible = true    
	end

     do
        local bunny_eid = world:new_entity("position", "rotation", "scale",
			"can_render", "mesh", "material",
			"name", "serialize",
			"can_select")
        local bunny = world[bunny_eid]
        bunny.name.n = "bunny"

        -- should read from serialize file        
        ms(bunny.scale, {5, 5, 5, 0}, "=")
        ms(bunny.position, {0, 0, 3, 1}, "=")
		ms(bunny.rotation, {0, -60, 0, 0}, "=")

		bunny.mesh.ref_path = "bunny.mesh"
		component_util.load_mesh(bunny)
     
		bunny.material.content[1] = {path = "bunny.material", properties = {}}
		component_util.load_material(bunny)
	 end

    
	-- do	-- pochuan
	-- 	local pochuan_eid = world:new_entity("position", "rotation", "scale",
	-- 	"can_render", "mesh", "material",
	-- 	"name", "serialize",
	-- 	"can_select")
	-- 	local pochuan = world[pochuan_eid]
	-- 	pochuan.name.n = "PoChuan"

	-- 	--mu.identify_transform(ms, pochuan)
	-- 	ms(pochuan.scale, {0.1, 0.1, 0.1}, "=")
	-- 	ms(pochuan.rotation, {-90, 0, 0,}, "=")

	-- 	component_util.load_mesh(pochuan.mesh,"pochuan.mesh")--, {calctangent=false})
	-- 	component_util.load_material(pochuan.material,{"pochuan.material"})
	-- 	--component_util.load_material(pochuan.material,{"bunny.material"})
	-- end

    -- 测试场景时，打开 PVPScene 加载BnH模型
    local PVPScene = require "modelloader.PVPScene"
	PVPScene.init(world, component_util, ms)

	-- do
	-- 	local stone_eid = world:new_entity("position", "rotation", "scale",
	-- 	"can_render", "mesh", "material",
	-- 	"name", "serialize", "can_select")

	-- 	local stone = world[stone_eid]
	-- 	stone.name.n = "texture_stone"

	-- 	mu.identify_transform(ms, stone)

	-- 	local function create_plane_mesh()
	-- 		local vdecl = bgfx.vertex_decl {
	-- 			{ "POSITION", 3, "FLOAT" },
	-- 			{ "NORMAL", 3, "FLOAT"},
	-- 			{ "TANGENT", 4, "FLOAT"},
	-- 			{ "TEXCOORD0", 2, "FLOAT"},
	-- 		}

	-- 		local lensize = 5

	-- 		return {
	-- 			handle = {
	-- 				group = {
	-- 					{
	-- 						vdecl = vdecl,
	-- 						vb = bgfx.create_vertex_buffer(
	-- 							{"ffffffffffff",
	-- 						lensize, -lensize, 0.0,
	-- 						0.0, 0.0, -1.0,
	-- 						0.0, 1.0, 0.0, 1.0,
	-- 						1.0, 0.0,

	-- 						lensize, lensize, 0.0,
	-- 						0.0, 0.0, -1.0,
	-- 						0.0, 1.0, 0.0, 1.0,
	-- 						1.0, 1.0,

	-- 						-lensize, -lensize, 0.0,
	-- 						0.0, 0.0, -1.0,
	-- 						0.0, 1.0, 0.0, 1.0,
	-- 						0.0, 0.0,

	-- 						-lensize, lensize, 0.0,
	-- 						0.0, 0.0, -1.0,
	-- 						0.0, 1.0, 0.0, 1.0,
	-- 						0.0, 1.0,
	-- 						}, vdecl)
	-- 					},
	-- 				}
	-- 			}
	-- 		}
	-- 	end

	-- 	stone.mesh.ref_path = ""	-- runtime mesh info
	-- 	stone.mesh.assetinfo = create_plane_mesh()


	-- 	stone.material.content[1] = {path = "stone.material", properties={}}
	-- 	component_util.load_material(stone)
	-- end

    local function create_entity(name, meshfile, materialfile)
        local eid = world:new_entity("rotation", "position", "scale", 
		"mesh", "material",
		"name", "serialize",
		"can_select", "can_render")

        local entity = world[eid]
        entity.name.n = name

        ms(entity.scale, {1, 1, 1}, "=")
        ms(entity.position, {0, 0, 0, 1}, "=") 
        ms(entity.rotation, {0, 0, 0}, "=")
		
		component_util.load_mesh(entity.mesh, meshfile)		
		component_util.load_material(entity.material,{materialfile})
        return eid
	end
	
	local hie_refpath = "hierarchy/test_hierarchy.hierarchy"
	-- do
	-- 	local assetpath = path.join(assetmgr.assetdir(), hie_refpath)
	-- 	path.create_dirs(path.parent(assetpath))
	-- 	local hierarchy = require "hierarchy"
	-- 	local root = hierarchy.new()

	-- 	root[1] = {
	-- 		name = "h1",
	-- 		transform = {
	-- 			t = {3, 4, 5},
	-- 			s = {0.01, 0.01, 0.01},
	-- 		}
	-- 	}

	-- 	root[2] = {
	-- 		name = "h2",
	-- 		transform = {
	-- 			t = {1, 2, 3},
	-- 			s = {0.01, 0.01, 0.01},
	-- 		}
	-- 	}

	-- 	root[1][1] = {
	-- 		name = "h1_h1",
	-- 		transform = {
	-- 			t = {3, 3, 3},
	-- 			s = {0.01, 0.01, 0.01},
	-- 		}
	-- 	}

	-- 	hierarchy.save(root, assetpath)
	-- end

	local hie_materialpath = "bunny.material"
    do
        local hierarchy_eid = world:new_entity("editable_hierarchy", "hierarchy_name_mapper",
            "scale", "rotation", "position", 
            "name", "serialize")
        local hierarchy_e = world[hierarchy_eid]

		hierarchy_e.name.n = "hierarchy_test"
		
		hierarchy_e.editable_hierarchy.ref_path = hie_refpath
		hierarchy_e.editable_hierarchy.root = assetmgr.load(hie_refpath, {editable=true})

        ms(hierarchy_e.scale, {1, 1, 1}, "=")
        ms(hierarchy_e.rotation, {0, 60, 0}, "=")
        ms(hierarchy_e.position, {10, 0, 0, 1}, "=")

		local entities = {
			h1 = "cube.mesh",
			h2 = "sphere.mesh",
			h1_h1 = "cube.mesh",		
		}

		local name_mapper = assert(hierarchy_e.hierarchy_name_mapper.v)
		for k, v in pairs(entities) do
			local eid = create_entity(k, v, hie_materialpath)	
			name_mapper[k] = eid
		end
		
		world:change_component(hierarchy_eid, "rebuild_hierarchy")
		world:notify()
	end
	
	do
        local hierarchy_eid = world:new_entity("editable_hierarchy", "hierarchy_name_mapper",
            "scale", "rotation", "position", 
            "name", "serialize")
		local hierarchy_e = world[hierarchy_eid]
		hierarchy_e.editable_hierarchy.ref_path = hie_refpath
		hierarchy_e.editable_hierarchy.root = assetmgr.load(hie_refpath, {editable=true})

		ms(hierarchy_e.scale, {1, 1, 1}, "=")
        ms(hierarchy_e.rotation, {0, -60, 0}, "=")
		ms(hierarchy_e.position, {-10, 0, 0, 1}, "=")

		hierarchy_e.name.n = "hierarchy_test_shared"	

		local entities = {
			h1 = "cylinder.mesh",
			h2 = "cone.mesh",
			h1_h1 = "sphere.mesh",
		}

		local name_mapper = assert(hierarchy_e.hierarchy_name_mapper.v)
		for k, v in pairs(entities) do
			name_mapper[k] = create_entity(k, v, hie_materialpath)
		end
		
		world:change_component(hierarchy_eid, "rebuild_hierarchy")
		world:notify()
	end

	do
		-- local ani_eid = world:new_entity("position", "scale", "rotation", 
		-- "mesh", "animation", "hierarchy", "material",
		-- "can_render", "can_select", 
		-- "name")

		-- local ani_e = world[ani_eid]
		-- ani_e.hierarchy.ref_path = "meshes/skeleton/skeleton.ozz"
		-- ani_e.hierarchy.builddata = assetmgr.load(ani_e.hierarchy.ref_path)
		-- ani_e.animation.ref_path = "meshes/animation/animation_base.ozz"
		-- ani_e.animation.handle = assetmgr.load(ani_e.animation.ref_path)

	end
end