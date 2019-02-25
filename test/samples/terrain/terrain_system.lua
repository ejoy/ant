local ecs = ...
local world = ecs.world


ecs.import "ant.render"
ecs.import "ant.editor"
ecs.import "ant.inputmgr"
ecs.import "ant.serialize"
ecs.import "ant.scene"
ecs.import "ant.timer"
ecs.import "ant.bullet"
ecs.import "ant.scene"

local lu = import_package "ant.render".light

local bgfx = require "bgfx"
local math = import_package "ant.math"
local math_util = math.util
local render = import_package "ant.render"
local shaderMgr = render.shader_mgr

local terrainClass = import_package "ant.terrain"

local UI_VIEW      	 = 255
local VIEWID_TERRAIN = 100 

-- local stack = nil
local math3d = require "math3d"
local stack = math.stack

local init_ambient = nil

local ctx = { stats = {} }     -- history debug 

--- ambient utils ---
local function gen_ambient_light_uniforms( terrain )
	for _,l_eid in world:each("ambient_light") do
		local am_ent = world[l_eid]
		local data = am_ent.ambient_light 

		local type = 1
		if data.mode == "factor" then 
			type = 0
		elseif data.mode == "gradient" then 
			type = 2
		end 
		terrain:set_uniform("ambient_mode",  {type, data.factor, 0, 0}  )
		terrain:set_uniform("ambient_skycolor", data.skycolor )  
		terrain:set_uniform("ambient_midcolor", data.midcolor  )
		terrain:set_uniform("ambient_groundcolor", data.groundcolor )
	end 
end 

local function gen_lighting_uniforms( terrain )
	for _,l_eid in world:each("directional_light") do 
		local dlight = world[l_eid]
		local l = dlight.light 
		terrain:set_uniform("u_lightDirection", stack(dlight.rotation, "dim") )
		terrain:set_uniform("u_lightIntensity", { l.intensity,0,0,0} )  
		terrain:set_uniform("u_lightColor",l.color  )
	end
end 

local function get_shadow_properties()
	local properties = {} 
	for _,l_eid in world:each("shadow_maker") do 
		local  sm_ent   = world[l_eid]
		local  uniforms = sm_ent.shadow_rt.uniforms 

		properties["u_params1"] = { name = "u_params1",type="v4",value = { uniforms.shadowMapBias,
																		   uniforms.shadowMapOffset,
																		   0.5,1} } 
		properties["u_params2"] = { name = "u_params2",type="v4",
									value = { uniforms.depthValuePow,
											  uniforms.showSmCoverage,
											  uniforms.shadowMapTexelSize, 0 } }
		properties["u_smSamplingParams"] = { name = "u_smSamplingParams",
								   type  ="v4",
								   value = { 0, 0, uniforms.ss_offsetx, uniforms.ss_offsety } }

		-- -- shadow matrices 
		properties["u_shadowMapMtx0"] = { name  = "u_shadowMapMtx0", type  = "m4", value = uniforms.shadowMapMtx0 }
		properties["u_shadowMapMtx1"] = { name  = "u_shadowMapMtx1", type  = "m4", value = uniforms.shadowMapMtx1 }
		properties["u_shadowMapMtx2"] = { name  = "u_shadowMapMtx2", type  = "m4", value = uniforms.shadowMapMtx2 }
		properties["u_shadowMapMtx3"] = { name  = "u_shadowMapMtx3", type  = "m4", value = uniforms.shadowMapMtx3 }
		--if sm_ent.shadow_rt.ready == true then 
			properties["s_shadowMap0"] = {  name = "s_shadowMap0", type = "texture", stage = 4, value = uniforms.s_shadowMap0 }
			properties["s_shadowMap1"] = {  name = "s_shadowMap1", type = "texture", stage = 5, value = uniforms.s_shadowMap1 }
			properties["s_shadowMap2"] = {  name = "s_shadowMap2", type = "texture", stage = 6, value = uniforms.s_shadowMap2 }
			properties["s_shadowMap3"] = {  name = "s_shadowMap3", type = "texture", stage = 7, value = uniforms.s_shadowMap3 }
		--end 
	end 
	return properties 
end 

local function update_property(name, property)
	local uniform = shaderMgr.get_uniform(name)        
	if uniform == nil  then
		log(string.format("property name : %s, is needed, but shadermgr not found!", name))
		return 
	end
	assert(uniform.name == name)
	--assert(property_type_description[property.type].type == uniform.type)
	
	if property.type == "texture" then 
		local stage = assert(property.stage)
		bgfx.set_texture(stage, assert(uniform.handle), assert(property.value))
		--print("texture ",stage,uniform.name,uniform.handle, property.value  )        		
	else
		local val = assert(property.value)

		local function need_unpack(val)
			if type(val) == "table" then
				local elemtype = type(val[1])
				if elemtype == "table" or elemtype == "userdata" or elemtype == "luserdata" then
					return true
				end
			end
			return false
		end
		
		if need_unpack(val) then
			-- print("uniform -- unpack",name,val )
			--bgfx.set_uniform(assert(uniform.handle), table.unpack(val))
		else
			-- print("uniform -- nounpack",name,val )
			--bgfx.set_uniform(assert(uniform.handle), val)
		end
	end
end

local function update_properties(shader, properties)
    if properties then
        -- check_uniform_is_match_with_shader(shader, properties)
        for n, p in pairs(properties) do
            update_property(n, p)
        end
    end
end

local function gen_shadow_uniforms( terrain )
	local properties = get_shadow_properties()
	update_properties(nil,properties)
end 

local function shadow_test()
end 

local function update_terrain( terrain )

	local ms = stack
	if init_ambient == nil  then 
		init_ambient = "true"
		-- already in system ,bgfx uniform only one copy in memory 
		-- gen_lighting_uniforms( terrain ) 
		-- gen_ambient_light_uniforms( terrain )
	end 
	-- must do this for dynamic light, if light do not move, could be run only once
	gen_lighting_uniforms( terrain ) 
	-- 找到获得 view，proj 的直接方法，不需要这里二次转换? 
	local camera = world:first_entity("main_camera")
    local camera_view, camera_proj = math_util.view_proj_matrix( camera ) -- ms, camera )

	--bgfx.set_view_rect( VIEWID_TERRAIN, 0, 0, ctx.width,ctx.height)
	bgfx.set_view_transform( VIEWID_TERRAIN,ms(camera_view,"m"),ms(camera_proj,"m") )	
	bgfx.touch( VIEWID_TERRAIN )
	
	-- for further anything like lod etc...
	-- terrain:update( view ,dir)        
	
	terrain:render( VIEWID_TERRAIN, ctx.width,ctx.height,prim_type, gen_shadow_uniforms )   -- "POINT","LINES"  -- for debug 
	              	
end


local function init_terrain(fbw, fbh, entity )

	ctx.width = fbw
	ctx.height = fbh

	local terrain_comp = entity.terrain 
	local pos_comp = entity.position 
	local rot_comp = entity.rotation 
	local scl_comp = entity.scale 

	local terrain = terrainClass.new()       	-- new terrain instance pvp
	terrain_comp.terrain_obj = terrain          -- assign to terrain component 

	local program_create_mode = 1
	-- load terrain level 
    -- gemotry create mode 2, extend, custom vertex decl
	terrain:load( terrain_comp.level_name ,   --"assets/build/terrain/pvp1.lvl",
					{   -- 自定义顶点格式
						{ "POSITION", 3, "FLOAT" },
						{ "TEXCOORD0", 2, "FLOAT" },
						{ "TEXCOORD1", 2, "FLOAT" },
						{ "NORMAL", 3, "FLOAT" },
					}
				)
    -- gemotry auto create mode 1, default 				
	-- terrain:load("assets/build/terrain/pvp1.lvl")  --chibi16.lvl")

	-- material create mode 
	if program_create_mode == 1 then 
		-- mothod 1, default 
		-- load from mtl setting 
		terrain:load_material( terrain_comp.level_material) --"assets/build/assetfiles/terrain_shadow.mtl")
	else 
		-- mothod 2
		-- or create manually
		terrain:load_program("terrain_shadow/vs_terrain_shadow","terrain_shadow/fs_terrain_shadow")
		terrain:create_uniform("u_mask","s_maskTexture","s",1)
		terrain:create_uniform("u_base","s_baseTexture","s",0)
		terrain:create_uniform("u_lightDirection","s_lightDirection","v4")
		terrain:create_uniform("u_lightIntensity","s_lightIntensity","v4")
		terrain:create_uniform("u_lightColor","s_lightColor","v4")
		terrain:create_uniform("u_showMode","s_showMode","s")   -- 0 default,1 = normal

		terrain:set_uniform("u_lightDirection",{1,1,1,1} )
		terrain:set_uniform("u_lightIntensity",{2.316,0,0,0} )  
		terrain:set_uniform("u_lightColor",{1,1,1,0.625} )
		terrain:set_uniform("u_showMode",0)     -- 0 = texture mode , 1 = normal line
	end 

	-- set terrain transform 
	local t = stack( pos_comp,"iT")
	local s = stack( scl_comp,"T")
	local r = stack( rot_comp,"T")
	terrain:set_transform { t = t, r = r, s = s }
end



-- terrain component
--  store terrain level name,material name, and terrain object into component
--  level name,material name need serialize into scene info file.
-- local terrain = ecs.component 
local schema = world.schema
schema:type "terrain_resource"
	.name "string" ""	--level_name
	.material "respath"	--level_material
schema:type "terrain"
	.path "terrain_resource"
local terraincomp = ecs.component "terrain" 
function terraincomp:init()
	self.terrain_obj = false
	return self
end

function terrain:delete()
    --self.terrain_obj.heightmap = nil 
    --self.terrain_obj.data = nil
    self.terrain_obj = nil
	-- collectgarbage()    
	print("delete terrain")
end 

-- terrain entity
local function create_terrain_entity( world, name  )
	local eid = world:create_entity {
		terrain = {
			path = {
				name = "levelname",
			}
		},
		material = {

		},
		position = {0, 0, 0, 1},
		rotation = {0, 0, 0, 0},
		scale = {1, 1, 1, 0},
		
		can_render = true,
		name = name,
		main_viewtag = true,
	}
	return world[eid], eid
end 



local terrain_sys = ecs.system "terrain_system"
terrain_sys.singleton "message"
terrain_sys.depend    "lighting_primitive_filter_system"
terrain_sys.depend 	  "entity_rendering"
terrain_sys.dependby  "end_frame"
terrain_sys.depend    "camera_controller"

function terrain_sys:init()
	do
		lu.create_directional_light_entity(world, "directional_light")
		lu.create_ambient_light_entity(world, "ambient_light", "gradient", {1, 1, 1,1})
	end
	--stack = self.math_stack  

	local Physics = world.args.Physics 
	local fb = world.args.fb_size

	-- we should read terrain entity'name ,compoent data from scene file 
	-- or system find a terrain entity already in entity list and create terrain delay
	-- sample usage 
	local tr_ent, pvp_eid = create_terrain_entity( world,"pvp")
	tr_ent.terrain.level_name = "assets/build/terrain/pvp1.lvl"
	tr_ent.terrain.level_material = "assets/depiction/terrain_shadow.mtl"
	-- stack(tr_ent.position, {147,0.25,205,1}, "=") -- old inverse 
	stack(tr_ent.position, {-147,0.25,-225,1}, "=")  
	--stack(tr_ent.position, {-32,0,-32,1}, "=")  
	stack(tr_ent.rotation, {0, 0, 0,}, "=")
	stack(tr_ent.scale, {1, 1, 1}, "=")
	init_terrain(fb.w, fb.h, tr_ent )

	-- world:add_component(pvp_eid,"terrain_collider")
	-- if Physics then 
	-- 	local shape_info = tr_ent.terrain_collider.info
	-- 	shape_info.obj, shape_info.shape = 
	-- 	Physics:create_terrainCollider( tr_ent.terrain.terrain_obj,shape_info,pvp_eid,{-147,0.25,-225},{0,0,0,1} )
	-- end 
	if Physics then 
	  Physics:add_component_terCollider(world, pvp_eid, "terrain_collider", stack)
	end 	  

	local chibi_ent,chibi_eid = create_terrain_entity( world,"chibi")
	chibi_ent.terrain.level_name = "assets/build/terrain/chibi16.lvl"
	chibi_ent.terrain.level_material = "assets//depiction/terrain_shadow.mtl"
	stack(chibi_ent.scale, {1, 1, 1}, "=")
	stack(chibi_ent.rotation, {0, 0, 0,}, "=")
	stack(chibi_ent.position, {60, 130, 60}, "=")
	init_terrain(fb.w, fb.h, chibi_ent )

	-- world:add_component(chibi_eid,"terrain_collider")
	-- if Physics then 
	-- 	local chibi_info = chibi_ent.terrain_collider.info 
	-- 	chibi_info.obj, chibi_info.shape = 
	-- 	Physics:create_terrainCollider( chibi_ent.terrain.terrain_obj, chibi_info,chibi_eid,{60,130,60},{0,0,0,1})
	-- end 
	
    if Physics then 
        -- add collider must remove shape from physics world,when entity removed 
		Physics:add_component_terCollider(world, chibi_eid, "terrain", stack)
        -- test delete entity,check deleteObject flow and content
        -- delete sample 1
		world:remove_entity(chibi_eid)
	end 	  
end

function terrain_sys:update()
	for _,eid in world:each("terrain") do              
        --if render_cu.is_entity_visible(world[eid]) then       -- vis culling 
		   local ter_ent = world[eid]
		   if ter_ent.terrain.terrain_obj then 
		      update_terrain( assert( ter_ent.terrain.terrain_obj) )
		   end 
        --end 
    end 
end
