-- dofile "libs/init.lua"
-- terrain System 
local ecs = ...
local world = ecs.world

package.path = package.path..';../clibs/terrain/?.lua;./clibs/terrain/?.lua;./test/?.lua;' 
package.cpath = package.cpath..';../clibs/terrain/?.dll;./clibs/terrain/?.dll;'

local bgfx = require "bgfx"
local nk = require "bgfx.nuklear"
local nkmsg = require "inputmgr.nuklear"

--local rhwi = require "render.hardware_interface"
--local task = require "editor.task"
--local s_logo = require "logo"
--local math3d = require "math3d"
--local utilmath = require "utilmath"

local loadfile = require "tested.loadfile"
local ch_charset = require "tested.charset_chinese_range"
local shaderMgr = require "render.resources.shader_mgr"

local terrainClass = require "terrain"
local camera_util = require "render.camera.util"

-- 做成 component 
local terrain = terrainClass.new()       	-- new terrain instance pvp
local terrain_chibi = terrainClass.new()    -- chibi 

local math3d_stack = nil 					--math3d.new()

-- canvas = iup.canvas{}
--local input_queue = inputmgr.queue(mapiup, canvas)
-- dlg = iup.dialog {
--   canvas,
--   title = "hello terrain world",
--   size = "HALFxHALF",
-- }


local ctx = { stats = {} }

local view = {200,12,200,1}
local dir = {0,0,0}

local last_x = 0
local last_y = 0
local pressed = false
local fly = true 

local lightIntensity = {1.316,0,0,0}
local lightColor = {1,1,1,0.625}
local show_mode = 0



-- joystick image
local joy_width = 320 
local joy_image = {}
local joy_base = {}
-- joystick pos & size
local joy_rc  = { x= (joy_width-200)/2,y=(joy_width-200)/2,w=200,h=200 }
local radius = 0.9  
local joy_size = 0.7 

local UI_VIEW = 255

local function joystick_init()
	joy_image = nk.loadImage("assets/build/textures/yaogan.tga")
	joy_base  = nk.loadImage("assets/build/textures/yaogandi.tga")
end 

local skinStyle = {
	['window'] = {
	['background'] = '#00000000',
	['fixed background'] = "#00000000",
	},
}

local function joystick_update()
	local move_dir = { x=0,y=0 }
	local rot_dir = { x =0,y=0 }

	nk.setStyle( skinStyle )   								
	if nk.windowBegin( "MoveJoy","ABC", 20, ctx.height-joy_width, joy_width, joy_width) then 
		nk.layoutSpaceBegin("static",-1,-1);
		nk.joystick("movejoy",joy_rc,joy_size,radius,move_dir,joy_base,joy_image)						
	end
	nk.windowEnd()
	if nk.windowBegin( "RotJoy","ABC", ctx.width-joy_width-20, ctx.height-joy_width, joy_width, joy_width ) then 
		nk.layoutSpaceBegin("static",-1,-1);
		nk.joystick("rotjoy",joy_rc,joy_size,radius,rot_dir,joy_base,joy_image)						
	end
	nk.windowEnd()

	nk.unsetStyle()
	return move_dir.x ,move_dir.y, rot_dir.x, rot_dir.y  
end 


function loadfonts(font,size,charset)
	return loadfile(font),size,charset
end 



local function process_input(message)
	-- local message = {}
	-- for _, msg,x,y,z,w,u in pairs(input_queue) do
	-- 	nkmsg.push(message, msg, x,y,z,w,u)
	-- end
	nk.input(message)

	local dirx,diry,r_dirx,r_diry = joystick_update()
	local camera = world:first_entity("main_camera")
	if dirx ~= 0 or diry ~= 0 then
		camera_util.move(math3d_stack, camera, -dirx, 0, -diry)
	end

	if r_dirx ~= 0 or r_diry ~= 0 then
		local rotate_speed = 1.5
		camera_util.rotate(math3d_stack, camera, r_dirx * rotate_speed, r_diry * rotate_speed)
	end


end 

-- 获取环境光组件信息
local function gen_ambient_light_uniforms()
	for _,l_eid in world:each("ambient_light") do
		local am_ent = world[l_eid]
		local data = am_ent.ambient_light.data 

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

-- 获取平行光源组件信息
local function gen_lighting_uniforms( terrain )
	
	for _,l_eid in world:each("directional_light") do 
		local dlight = world[l_eid]
		local l = dlight.light.v 
		terrain:set_uniform("u_lightDirection", math3d_stack(dlight.rotation.v, "dim") )
		terrain:set_uniform("u_lightIntensity", { l.intensity,0,0,0} )  
		terrain:set_uniform("u_lightColor",l.color  )
	end 
end 

local message_queue = {}

local init_ambient = nil 

local function mainloop()

	if init_ambient == nil  then 
		init_ambient = "true"
		-- get ambient parameters 
		gen_lighting_uniforms( terrain ) 
		gen_ambient_light_uniforms( terrain )
	end 
	print("ambient------------"..init_ambient)

	-- -- input
	process_input(message_queue)
	
	-- control camera 
	local result,height = terrain:get_height( view[1],view[3] )
	if result == true and fly == false then 
		view[2] = height + 5  
	end 

    -- terrain chibi 
	terrain_chibi:render( ctx.width,ctx.height)
    -- terrain pvp 
	terrain:update( view ,dir)                        -- for further anything 
	terrain:render( ctx.width,ctx.height,prim_type)   --"POINT","LINES"  -- for debug 

	-- ui input --
	local ortho_mtx = math3d_stack( { type = "ortho", l = 0, r = ctx.width, b = ctx.height, t = 0, n = 0, f = 100, h = false }, "m")  
	--local ortho_mtx = math3d_stack( { 2.0/ctx.width, 0.0, 0.0, 0.0,   0.0,-2.0/ctx.height, 0.0, 0.0,  0.0, 0.0,-1.0, 0.0,  -1.0, 1.0, 0.0, 1.0}, "m") 

	bgfx.set_view_transform(UI_VIEW,nil,ortho_mtx)	
	nk.update()
	
	message_queue = {}
	--bgfx.frame()
end


local function init(fbw, fbh)
	-- rhwi.init(iup.GetAttributeData(canvas,"HWND"), fbw, fbh)
	-- bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)
	-- bgfx.set_debug "T"

	ctx.width = fbw
	ctx.height = fbh

	-- nk init
	nk.init {
		view = UI_VIEW,
		width = fbw,
		height = fbh,
		decl = bgfx.vertex_decl {
			{ "POSITION", 2, "FLOAT" },
			{ "TEXCOORD0", 2, "FLOAT" },
			{ "COLOR0", 4, "UINT8", true },
		},
		texture = "s_texColor",
		state = bgfx.make_state {
			WRITE_MASK = "RGBA",
			BLEND = "ALPHA",
		},
		prog = shaderMgr.programLoad("ui/vs_nuklear_texture.sc","ui/fs_nuklear_texture.sc"),

		fonts = {
			{ "宋体行楷", loadfonts("build/fonts/stxingka.ttf",50, ch_charset()  ), },
		},
	}	

	local program_create_mode = 0

	-- load terrain level 
    -- gemotry create mode 
	terrain:load("assets/build/terrain/pvp1.lvl",      			  -- 自定义顶点格式
					{
						{ "POSITION", 3, "FLOAT" },
						{ "TEXCOORD0", 2, "FLOAT" },
						{ "TEXCOORD1", 2, "FLOAT" },
						{ "NORMAL", 3, "FLOAT" },
					}
				)

	 terrain_chibi:load("assets/build/terrain/chibi16.lvl")  	  -- 默认顶点格式

	-- material create mode 
	if program_create_mode == 1 then 
		-- load from mtl setting 
		terrain:load_meterial("assets/build/terrain/terrain.mtl")
	else 
		-- or create manually
		terrain:load_program("terrain/vs_terrain.sc","terrain/fs_terrain.sc")
		terrain:create_uniform("u_mask","s_maskTexture","i1",1)
		terrain:create_uniform("u_base","s_baseTexture","i1",0)
		terrain:create_uniform("u_lightDirection","s_lightDirection","v4")
		terrain:create_uniform("u_lightIntensity","s_lightIntensity","v4")
		terrain:create_uniform("u_lightColor","s_lightColor","v4")
		terrain:create_uniform("u_showMode","s_showMode","i1")   -- 0 default,1 = normal

		-- 初始值必须填写,这个限制有益? 或可以修改 terrain.lua 让 uniform 的初始值可以不填写
		terrain:set_uniform("u_lightDirection",{1,1,1,1} )
		terrain:set_uniform("u_lightIntensity",{1.316,0,0,0} )  
		terrain:set_uniform("u_lightColor",{1,1,1,0.625} )
		terrain:set_uniform("u_showMode",0)  
	end 

	terrain_chibi:load_meterial("assets/build/terrain/terrain.mtl")  -- 文件加载材质
	terrain_chibi:create_uniform("u_showMode","s_showMode","i1")     -- 可以手工增加uniform，方便测试 
	terrain_chibi:set_uniform("u_showMode",0)   				     -- 0= default, 1 = display normal line

	terrain:set_transform { t= {147,0,225,1},r= {0,0,0},s={1,1,1,1}}
	terrain_chibi:set_transform { t= {0,150,0,1},r= {0,0,0},s={1,1,1,1}}

	-- ui init
	joystick_init()

	-- 独立app 测试代码
	--task.loop(mainloop)
end

local terrain_sys = ecs.system "terrain_system"
terrain_sys.singleton "math_stack"
terrain_sys.singleton "message_component"

terrain_sys.depend "entity_rendering"
terrain_sys.dependby "end_frame"

-- ecs 需要增加 componet 从文件中创建加载的流程
-- update 访问 component ,mesh,terrain 可同流程不同结构


function terrain_sys:init()
	math3d_stack = self.math_stack
	local fb = world.args.fb_size

	init(fb.w, fb.h)

	--
	local message = {}
	function message:button(...)
		nkmsg.push(message_queue, "button", ...)
	end

	function message:motion(...)
		nkmsg.push(message_queue, "motion", ...)
	end

	function message:keypress(...)
		nkmsg.push(message_queue, "keypress", ...)
	end


	local observers = self.message_component.msg_observers
	observers:add(message)
end

function terrain_sys:update()
	mainloop()
end




-- function canvas:resize_cb(w,h)
-- 	if init then
-- 		init(self, w, h)
-- 		init = nil
-- 	else 
-- 		nk.resize(w,h)
-- 	end
-- 	bgfx.set_view_rect(0, 0, 0, w, h)
-- 	bgfx.reset(w,h, "v")
-- 	ctx.width = w
-- 	ctx.height = h
-- end

-- function canvas:keypress_cb(key, press)
-- 	if key ==  iup.K_F1 and press == 1 then
-- 		ctx.debug = not ctx.debug
-- 		bgfx.set_debug( ctx.debug and "S" or "")
-- 	end
-- 	if key == iup.K_F12 and press == 1 then
-- 		bgfx.request_screenshot()
-- 	end
-- end



-- function canvas:action(x,y)
-- 	mainloop()
-- end

-- dlg:showxy(iup.CENTER,iup.CENTER)
-- dlg.usersize = nil

-- -- to be able to run this script inside another context
-- if (iup.MainLoopLevel()==0) then
-- 	iup.MainLoop()
-- 	iup.Close()
-- end
