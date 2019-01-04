local ecs = ...
local world = ecs.world

-- test usage, need combine into world
-- local Physics = nil 
-- if world.Physics == nil then 
--     package.path = package.path..';./clibs/terrain/?.lua;./test/?.lua;'
--     package.path = package.path..';./clibs/bullet/?.lua;'
  
--     local bullet_world = require "bulletworld"
--     world.Physics = bullet_world.new()
-- end 
-- Physics = world.Physics 


ecs.import "render.constant_system"
ecs.import "inputmgr.message_system"

--ecs.import "render.math3d.math_component"
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

local math3d = require "math3d"
local math = import_package "math"
local stack = math.stack


local update_direction_light_sys = ecs.system "direction_light_system"
--update_direction_light_sys.singleton "math_stack"

function update_direction_light_sys:update()
    if true then
       return
    end

	--local ms = self.math_stack
	local ms = stack 

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

--add_entity_sys.singleton "math_stack"
add_entity_sys.singleton "constant"

add_entity_sys.depend "constant_init_sys"
add_entity_sys.dependby "message_system"





function add_entity_sys:init()
	--local ms = self.math_stack
	local ms = stack 
	local Physics = world.args.Physics 

	do
		local leid = lu.create_directional_light_entity(world)
		world:add_component(leid, "position", "mesh", "material", "can_render", "scale") --, "name")
		local lentity = world[leid]

		local lightcomp = lentity.light 
		lightcomp.color = {1,1,1,1}
		lightcomp.intensity = 2.0

		ms(lentity.rotation, {45, 145, -45}, "=")
		ms(lentity.position, {200, 200, 200}, "=")
		

		ms(lentity.scale, {1.1, 1.1, 1.1}, "=")

		lentity.name = "directional_light"

		-- add tested for ambient 
		local am_eid = lu.create_ambient_light_entity(world)
		local am_entity = world[ am_eid]
		local ambient_comp = am_entity.ambient_light
		ambient_comp.mode = "gradient"
		ambient_comp.skycolor = {1,1,1,1}
		ambient_comp.midcolor  = {0.9,0.9,1,1}
		ambient_comp.groundcolor  = {0.50,0.74,0.68,1}
		--ambient_comp.skycolor = {0.8,0.8,0.8,1} --{0.28,0,1,1}
		--ambient_comp.midcolor = {0,1,0,1}
		--ambient_comp.groundcolor = {0,0,1,1}
		--ambient_comp.factor = 0.25
		lentity.name = "ambient_light"

		component_util.load_mesh(lentity.mesh,"sphere.mesh")		
		component_util.load_material(lentity.material,{"light_bulb.material"})

		lentity.can_render = true    
	end

     do
        local bunny_eid = world:new_entity("position", "rotation", "scale",
			"can_render", "mesh", "material",
			"name", "serialize",
			"can_select")
        local bunny = world[bunny_eid]
        bunny.name = "bunny"

        -- should read from serialize file        
        ms(bunny.scale, {5, 5, 5, 0}, "=")
        --ms(bunny.position, {0, -2.5, 3, 1}, "=")
        ms(bunny.position, {-32, 4.5, -32, 1}, "=")
		ms(bunny.rotation, {0, -60, 0, 0}, "=")
 
		bunny.mesh.ref_path = "bunny.mesh"
		component_util.load_mesh(bunny.mesh,"bunny.mesh")
     
		bunny.material.content[1] = {path = "bunny.material", properties = {}}
        component_util.load_material(bunny.material)

		-- normal usage 
		-- world:add_component(bunny_eid, "box_collider")	
        -- local shape_info = bunny.box_collider.info
        -- shape_info.center[1] = 0  shape_info.center[2] = 0  shape_info.center[3] = 0
        -- shape_info.sx = 5         shape_info.sy = 5         shape_info.sz = 5
		-- shape_info.obj_idx = bunny_eid   -- or any combine mode 
        -- -- notice convert bunny position from stack pid to {...}
		-- shape_info.obj, shape_info.shape = Physics:create_collider("box",shape_info, bunny_eid, {-32,-22.5,-32}, {0,0,0,1} )
		
		if Physics then 
			-- collider samples 
			local shape_info ={ center = {}, } 
			shape_info.center[1] = 0  shape_info.center[2] = 0.5  shape_info.center[3] = 0
			-- for  box
			shape_info.sx = 5         shape_info.sy = 5           shape_info.sz = 5 
			-- for  sapsule and cylinder
			shape_info.radius = 1     shape_info.height = 5 
			-- for  sphere 
			shape_info.radius = 1       

			shape_info.obj_idx = bunny_eid   -- or any combine mode 
			shape_info.type = "sphere"
			-- use info
			Physics:add_component_collider(world,bunny_eid,"sphere",ms,shape_info) 
			--Physics:add_component_collider(world,bunny_eid,"box",ms,shape_info)
			-- not info,auto create 
			--Physics:add_component_collider(world,bunny_eid,"sphere",ms) 

			-- delete sample 2 test
			local obj, shape = Physics:create_collider("box",shape_info, bunny_eid, {-32,-22.5,-32}, {0,0,0,1} )
			Physics:delete_collider(obj,shape)

			-- delete sample 3 combine create and delete
			-- create collider, equal create_collider
			local base_shape = Physics:create_shape("compound")
			local shape = Physics:create_shape("box",shape_info)
			Physics.world:add_to_compound(base_shape,shape,{shape_info.center[1],shape_info.center[2],shape_info.center[3]}, {0,0,0,1} )
			local object = Physics:create_object(base_shape, bunny_eid,{-32,-22.5,-32},{0,0,0,1} )
			-- delete collider 
			Physics:delete_collider(object,base_shape)
		end 
	 end
	
	 
	
    -- 测试场景时，打开 PVPScene 加载BnH模型
    local PVPScene = require "modelloader.PVPScene_phy"
	PVPScene.init( world, component_util, ms)

	
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

end