local ecs = ...
local world = ecs.world

local bgfx = require "bgfx"
local math_util = require "math.util"
local render_cu = require "render.components.util"
local shaderMgr = require "render.resources.shader_mgr"
local camera_util = require "render.camera.util"

local math3d = require "math3d"
local stack = require "math.stack"    
local texLoad = require "terrain.utiltexture"

local VIEWID_UI    	 = 255
local VIEWID_SKY     = 100 

local ctx = { stats = {} }

-- sky component
--   store level sky parameters, shader name 
--   and need serialize into scene info file.
local sky = ecs.component_struct "sky" {
    info = {
        type = "userdata",
        default = { 
            type = "skybox", --"procedural",
            cubmap = {
                left = "",
                right = "",
                front = "",
                back = "",
                top = "",
                bottom ="",
            },
            skydome = {
                sun_direction = {0,0,0},
                turbidity = 2.0,
            },
            material_name = "material",

            -- runtime data 
            sky_obj = {}, 
        },
        
        save = function (v, arg)
            assert(type(v) == "string")
            return v
        end,

        load = function (v, arg)
            assert(type(v) == "string")
            return v 
        end,
    },
}

function sky:delete()
    self.sky_obj = nil
end 

local function load_cubemap(tex_name)
    local info = {} 
    local th = texLoad( tex_name,info )
    return th 
end 

-- sky entity
local function create_sky_entity( world, name  )
	local eid = world:new_entity(
		"sky",  
		"material", 
		"position","rotation","scale",
		"can_render",
		"name")
	local entity = assert( world[eid] )
	entity.name = name 
	return entity,eid  
end

local function load_material(sky_comp)
    local cu 	= require "render.components.util"
    local material = {}
    cu.load_material( material, {sky_comp.info.material_name} )
    sky_comp.info.sky_obj.prog = material[1].materialinfo.shader.prog 
    sky_comp.info.sky_obj.material = material       -- how to destroy?
    return material 
end 

-- skybox --
local function create_skybox(sky_comp,sky_obj)
    local vdecl = {
        {"POSITION",3,"FLOAT"},
        {"COLOR0", 4, "UINT8", true },
    }
    local vertices = {
        "fffd",
        -1,  1,  1, 0xffffffff, --0xffffffff,   -- ABGR
         1,  1,  1, 0xffffffff, --0xffffffff,
         1, -1,  1, 0xffffffff, --0x000000ff,
        -1, -1,  1, 0xffffffff, --0x000000ff, 
         1,  1, -1, 0xffffffff, --0xffffffff,  
        -1,  1, -1, 0xffffffff, --0xffffffff,
        -1, -1, -1, 0xffffffff, --0x00ff00ff,
         1, -1, -1, 0xffffffff, --0x00ff00ff,
    }
    local indices = {
        0, 1, 2, 2, 3, 0,   -- Front
        1, 4, 7, 7, 2, 1,   -- Right
        4, 5, 6, 6, 7, 4,   -- Back
        5, 0, 3, 3, 6, 5,   -- Left
        5, 4, 1, 1, 0, 5,   -- Top
        3, 2, 7, 7, 6, 3    -- Bottom
    }
    sky_obj.vdecl = bgfx.vertex_decl( vdecl )    
    sky_obj.vbh = bgfx.create_vertex_buffer( vertices, sky_obj.vdecl)
    sky_obj.ibh = bgfx.create_index_buffer( indices )
    sky_obj.material = load_material( sky_comp ) 
    sky_obj.texh = material[1].properties["s_texCube"].value 
    sky_obj.type = "skybox"
end 




----- procedural sky ----------
local sky_luminance_xyzTable = {
    [ 0.0 ] = { 0.308, 0.308, 0.411 } ,
    [ 1.0 ] = { 0.308, 0.308, 0.410 } ,
    [ 2.0 ] = { 0.301, 0.301, 0.402 } ,
    [ 3.0 ] = { 0.287, 0.287, 0.382 } ,
    [ 4.0 ] = { 0.258, 0.258, 0.344 } ,
    [ 5.0 ] = { 0.258, 0.258, 0.344 } ,
    [ 6.0 ] = { 0.258, 0.258, 0.344 } ,
    [ 7.0 ] = { 0.962851, 1.000000, 1.747835 },
    [ 8.0 ] = { 0.967787, 1.000000, 1.776762 },
    [ 9.0 ] = { 0.970173, 1.000000, 1.788413 },
    [ 10.0] = { 0.971431, 1.000000, 1.794102 },
    [ 11.0] = { 0.972099, 1.000000, 1.797096 },
    [ 12.0] = { 0.972385, 1.000000, 1.798389 },
    [ 13.0] = { 0.972361, 1.000000, 1.798278 },
    [ 14.0] = { 0.972020, 1.000000, 1.796740 },
    [ 15.0] = { 0.971275, 1.000000, 1.793407 },
    [ 16.0] = { 0.969885, 1.000000, 1.787078 },
    [ 17.0] = { 0.967216, 1.000000, 1.773758 },
    [ 18.0] = { 0.961668, 1.000000, 1.739891 },
    [ 19.0] = { 0.961668, 1.000000, 1.739891 },    
    [ 20.0] = { 0.264, 0.264, 0.352 },
    [ 21.0] = { 0.264, 0.264, 0.352 },
    [ 22.0] = { 0.290, 0.290, 0.386 },
    [ 23.0] = { 0.303, 0.303, 0.404 },
}

local sun_luminance_xyzTable = {
    [ 0.0 ] = { 0.0000000, 0.000000,  0.000000  },
    [ 1.0 ] = { 0.0000000, 0.000000,  0.000000  },
    [ 2.0 ] = { 0.0000000, 0.000000,  0.000000  },
    [ 3.0 ] = { 0.0000000, 0.000000,  0.000000  },    
    [ 4.0 ] = { 0.0000000, 0.000000,  0.000000  },    
    [ 5.0 ] = { 0.0000000, 0.000000,  0.000000  },
    [ 6.0 ] = { 0.0000000, 0.000000,  0.000000  },
    [ 7.0 ] = { 12.703322, 12.989393, 9.100411  },
    [ 8.0 ] = { 13.202644, 13.597814, 11.524929 },
    [ 9.0 ] = { 13.192974, 13.597458, 12.264488 },
    [ 10.0] = { 13.132943, 13.535914, 12.560032 },
    [ 11.0] = { 13.088722, 13.489535, 12.692996 },
    [ 12.0] = { 13.067827, 13.467483, 12.745179 },
    [ 13.0] = { 13.069653, 13.469413, 12.740822 },
    [ 14.0] = { 13.094319, 13.495428, 12.678066 },
    [ 15.0] = { 13.142133, 13.545483, 12.526785 },
    [ 16.0] = { 13.201734, 13.606017, 12.188001 },
    [ 17.0] = { 13.182774, 13.572725, 11.311157 },
    [ 18.0] = { 12.448635, 12.672520, 8.267771  },
    [ 19.0] = { 12.448635, 12.672520, 8.267771  },
    [ 20.0] = { 0.0000000, 0.0000000, 0.000000  },
    [ 21.0] = { 0.0000000, 0.0000000, 0.000000  },
    [ 22.0] = { 0.0000000, 0.0000000, 0.000000  },
    [ 23.0] = { 0.0000000, 0.0000000, 0.000000  },
}

-- Turbidity tables. Taken from:
-- A. J. Preetham, P. Shirley, and B. Smits. A Practical Analytic Model for Daylight. SIGGRAPH ’99
-- Coefficients correspond to xyY colorspace.
local ABCDE =
{
    { -0.2592, -0.2608, -1.4630 },
    {  0.0008,  0.0092,  0.4275 },
    {  0.2125,  0.2102,  5.3251 },
    { -0.8989, -1.6537, -2.5771 },
    {  0.0452,  0.0529,  0.3703 },
};
local ABCDE_t =
{
    { -0.0193, -0.0167,  0.1787 },
    { -0.0665, -0.0950, -0.3554 },
    { -0.0004, -0.0079, -0.0227 },
    { -0.0641, -0.0441,  0.1206 },
    { -0.0033, -0.0109, -0.0670 },
};

local function compute_perez_coeff( turbidity,perez_coeff)
    for i = 1, 5 do 
        -- perez_coeff[idx+0] = ABCDE_t[i][1] * turbidity + ABCDE[i][1]
        -- perez_coeff[idx+1] = ABCDE_t[i][2] * turbidity + ABCDE[i][2]
        -- perez_coeff[idx+2] = ABCDE_t[i][3] * turbidity + ABCDE[i][3]
        -- perez_coeff[idx+3] = 0
        -- idx = idx + 4
        local t = {}
        t[1] = ABCDE_t[i][1] * turbidity + ABCDE[i][1]
        t[2] = ABCDE_t[i][2] * turbidity + ABCDE[i][2]
        t[3] = ABCDE_t[i][3] * turbidity + ABCDE[i][3]
        t[4] = 0
        perez_coeff[i] = t
    end 
end 


local function lerp(a,b,t)
    return a+(b-a)*t 
end 
local function interpolate(ltime,lvalue,utime,uvalue,time)
    local r = (time-ltime)/(utime-ltime);
    local c = {}
    c[1] = lerp(lvalue[1],uvalue[1],r)
    c[2] = lerp(lvalue[2],uvalue[2],r)
    c[3] = lerp(lvalue[3],uvalue[3],r)
    return c 
end 
local function get_dynamic_value(xyzTable,key)
    local xyz = xyzTable
    local up_time = math.ceil( key + 0.000001 )
    local lower_time = math.floor(up_time -1  )
    local upper = xyz[ up_time  ]
    local lower = xyz[ lower_time ]
    if lower == nil or upper == nil then 
      -- check
    end 
    if lower == nil then return upper end 
    if upper == nil then return lower end 
    return interpolate(lower_time,lower,up_time,upper,key)
end 


local function create_procedural_sky(sky_comp,sky_obj)
    local vdecl = {
        {"POSITION",2,"FLOAT"},
    }
    local vert_count = 32 
    local horz_count = 32 
    local vertices = {"ff",}
    local idx = 2
    for i=1, vert_count do 
        for j=1, horz_count do 
            vertices[idx] =  (j-1)/(horz_count -1 )*2.0-1.0  idx = idx + 1 
            vertices[idx] =  (i-1)/(vert_count -1 )*2.0-1.0  idx = idx + 1
            --vertices[idx] =  0                              idx = idx + 1 
        end 
    end  

    local indices = {}
    local k = 1
    for i=0, vert_count-2 do 
        for j=0, horz_count-2 do 
           indices[k] = (j+0 + horz_count*(i)) k = k + 1
           indices[k] = (j+1 + horz_count*(i)) k = k + 1
           indices[k] = (j+0 + horz_count*(i+1)) k = k + 1

           indices[k] = (j+1 + horz_count*(i)) k = k + 1
           indices[k] = (j+1 + horz_count*(i+1)) k = k + 1
           indices[k] = (j+0 + horz_count*(i+1)) k = k + 1
        end 
    end 
    sky_obj.vdecl = bgfx.vertex_decl( vdecl )    
    sky_obj.vbh = bgfx.create_vertex_buffer( vertices, sky_obj.vdecl)
    sky_obj.ibh = bgfx.create_index_buffer( indices )
    sky_obj.material = load_material( sky_comp ) 
    sky_obj.type = "skyprocedural"

    sky_obj.latitude =  -35
    sky_obj.turbidity = 2.3
    sky_obj.month = 7
end 

local delta = 0
local eclipticObliquity = math.rad(23.4) 
local function update_sun_orbit( sky )
    local month = sky.month 
    local day = 30* month + 15
    local lamda = 280.45 + 0.985674 *day 
    lamda = math.rad(lamda)
    delta = math.asin( math.sin(eclipticObliquity)*math.sin(lamda))
end 

local function update_sun_position( sky_obj, hour )
    local ms = stack 
    local latitude = math.rad(sky_obj.latitude )
    local h = hour* 3.1415926/12.0

    local azimuth = math.atan2(
                        math.sin(h),
                        math.cos(h) * math.sin(latitude) - math.tan( delta) * math.cos(latitude)
                    )

    local altitude = math.asin( 
        math.sin(latitude) * math.sin(delta) + math.cos(latitude) * math.cos(delta) * math.cos(h)
    )   
    
    local quat = ms( {type="q", axis={0, 1, 0}, angle={ math.deg(-azimuth)}}, "P")
    local dir = ms(  quat , {1,0,0,0}, "*P") 
    local temp = ms(dir,"T")
    local v = ms({0,1,0}, temp,"xP")
    --local temp1 = ms(v,"T")
    quat = ms( {type="q", axis= v, angle={ math.deg(altitude) } }, "P")
    local sundir = ms( quat,dir,"*iP")
    local sun_dir = ms(sundir,"T")
    return sun_dir 
end 

local function update_sun( sky_obj, time  )
    update_sun_orbit( sky_obj )
    sky_obj.sun_direction = update_sun_position( sky_obj,time -12.0)
end 



local M_XYZ2RGB = {
	3.240479 , -0.969256 , 0.055648,
	-1.53715 , 1.875991 , -0.204043,
	-0.49853 , 0.041556 , 1.057311,
};

local function XYZToRGB( xyz )
    local rgb = {}
    rgb[1] = M_XYZ2RGB[1] * xyz[1] + M_XYZ2RGB[4] * xyz[2] + M_XYZ2RGB[7] * xyz[3];
    rgb[2] = M_XYZ2RGB[2] * xyz[1] + M_XYZ2RGB[5] * xyz[2] + M_XYZ2RGB[8] * xyz[3];
    rgb[3] = M_XYZ2RGB[3] * xyz[1] + M_XYZ2RGB[6] * xyz[2] + M_XYZ2RGB[9] * xyz[3];
    return rgb;
end 

--- make properties as common function ,it is useful

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
            bgfx.set_uniform(assert(uniform.handle), table.unpack(val))
        else
            bgfx.set_uniform(assert(uniform.handle), val)
        end
    end
end

local function update_properties(shader, properties)
    if properties then
        for n, p in pairs(properties) do
            update_property(n, p)
        end
    end
end

local perez_coeff = {}
local function update_procedural_sky( sky_obj, time )

    local sky_xyz = get_dynamic_value(sky_luminance_xyzTable,time)
    local sun_xyz = get_dynamic_value(sun_luminance_xyzTable,time)
    sky_obj.sky_color = XYZToRGB(sky_xyz)
    sky_obj.sun_color = XYZToRGB(sun_xyz)      

    compute_perez_coeff(sky_obj.turbidity, perez_coeff )

    local properties = {} 
    
    local prop = sky_obj.material[1].properties["u_parameters"]
    properties["u_parameters"] = { 
        name = "u_parameters", type="v4", 
        value = { prop.value[1], prop.value[2] , prop.value[3], time  },
    } 
    properties["u_skyLuminanceXYZ"] = {
        name = "u_skyLuminanceXYZ", type = "v4",
        value = {sky_xyz[1], sky_xyz[2], sky_xyz[3],1 }
    }   
    properties["u_sunDirection"] = { type = "v4",name = "u_sunDirection", 
        value = { sky_obj.sun_direction[1],sky_obj.sun_direction[2],sky_obj.sun_direction[3],0}
    }
    properties["u_perezCoeff"] = {
        name = "u_perezCoeff", type = "v4",
        value =  perez_coeff , 
    } 
    -- make update_properties as common function ,later 
    update_properties( nil, properties);
end 

local function render_procedural_sky()
end 

local function dynamic_value_controller()
end 


local function init_sky(fbw, fbh, entity )

	ctx.width  = fbw
	ctx.height = fbh

	local sky_comp = entity.sky 
	local pos_comp = entity.position 
	local rot_comp = entity.rotation 
	local scl_comp = entity.scale 


    local sky_mode = sky_comp.info.type 
    local sky_obj  = sky_comp.info.sky_obj 
    local material_name = sky_comp.info.material_name
    
    if sky_mode == "skybox" then 
        create_skybox(sky_comp,sky_obj)
    elseif sky_mode == "skyprocedural" then 
        create_procedural_sky(sky_comp,sky_obj)
    end 

    sky_obj.pos_comp = entity.position 
	sky_obj.rot_comp = entity.rotation 
	sky_obj.scl_comp = entity.scale 

end



local function update_skybox_property( sky  )
    -- local properties = {} 
    -- local li = sky.li
    -- local texh = sky.texh 
    -- properties["s_texCube"] = { 
    --     name = "s_texCube", type="texture", 
    --     stage = 0, value = texh,
    -- } 
    -- properties["u_lightScale"] = {
    --     name = "u_lightScale",type="v4",
    --     value = {li,0,0,0},
    -- }
    -- -- make update_properties as common function ,later 
    -- update_properties( nil, properties);

    -- from setting 
    update_properties( sky.material, sky.material[1].properties )    -- material file
end 

local function render_sky( viewId, sky )
    -- update_properties( sky.material, sky.material[1].properties ) 
    local prim_type = "TRISTRIP"
    local state =  bgfx.make_state( { CULL="CW", PT = prim_type ,
                                      WRITE_MASK = "RGBAZ",
                                      DEPTH_TEST = "LEQUAL",
                                      
                                    } , nil)        									
    bgfx.set_state( state )
    bgfx.set_vertex_buffer( sky.vbh )
    bgfx.set_index_buffer( sky.ibh )     							 			  
    bgfx.submit( viewId, sky.prog)
end 

local function update_sky( sky,time )
	local ms = stack
	local camera = world:first_entity("main_camera")
    local camera_view, camera_proj = math_util.view_proj_matrix( camera )
    local pos = stack(camera.position,"T")
	--bgfx.set_view_rect( VIEWID_TERRAIN, 0, 0, ctx.width,ctx.height)
	bgfx.set_view_transform( VIEWID_SKY, ms(camera_view,"m"),ms(camera_proj,"m") )	
    bgfx.touch( VIEWID_SKY )
    -- matrix persistant must needed ! this make optimized invalid.
    local mat = stack({type="srt", s= sky.scl_comp, r= sky.rot_comp, t= pos}, "m")
    bgfx.set_transform(mat)

    update_sun( sky, time )

    if sky.type == "skyprocedural" then 
        update_procedural_sky( sky, time )
    elseif sky.type == "skybox" then 
        update_skybox_property( sky )
    end 
    render_sky( VIEWID_SKY, sky  )
end


ecs.import "timer.timer"

local sky_system = ecs.system "sky_system"
sky_system.singleton "message"
sky_system.depend 	 "entity_rendering"
sky_system.dependby  "end_frame"
sky_system.singleton "timer"

function sky_system:init()
	local Physics = world.args.Physics 
	local fb = world.args.fb_size
 
    local sky_ent = create_sky_entity( world,"sky")
    --sky_ent.sky.info.type ="skybox"
    --sky_ent.sky.info.material_name = "assets/depiction/skybox.material"
    sky_ent.sky.info.type = "skyprocedural"
    sky_ent.sky.info.material_name = "assets/depiction/skyprocedural.material"
	stack(sky_ent.scale, {1, 1, 1}, "=")
	stack(sky_ent.rotation, {0, 0, 0,}, "=")
	stack(sky_ent.position, {0, 0, 0}, "=")
    init_sky( fb.w, fb.h, sky_ent )
end

local time = 0 
function sky_system:update()
    local deltaTime =  self.timer.delta
    time = time + deltaTime*0.001 
    time = math.fmod(time,24.0)
    --print("daytime :",time)
	for _,eid in world:each("sky") do              
	   local sky_ent = world[eid]
       if sky_ent then 
          local sky_obj = sky_ent.sky.info.sky_obj
	      update_sky( assert( sky_obj ), time  )
	   end 
    end 
end
