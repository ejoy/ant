dofile "libs/init.lua"
package.path = package.path..';../clibs/terrain/?.lua;./clibs/terrain/?.lua;./test/?.lua;' 
package.cpath = package.cpath..';../clibs/terrain/?.dll;./clibs/terrain/?.dll;'

local bgfx = require "bgfx"
local rhwi = require "render.hardware_interface"
local nk = require "bgfx.nuklear"
local task = require "editor.task"


local s_logo = require "logo"

local mapiup = require "inputmgr.mapiup"
local inputmgr = require "inputmgr"
local nkmsg = require "inputmgr.nuklear"

local math3d = require "math3d"
local mathu = require "math.util"

local loadfile = require "tested.loadfile"
local ch_charset = require "tested.charset_chinese_range"

local shaderMgr = require "render.resources.shader_mgr"

local terrainClass = require "terrain"
local utilmath = require "utilmath"
local eu = require "editor.util"


local terrain = terrainClass.new()       	-- new terrain instance pvp
local terrain_chibi = terrainClass.new()    -- chibi 

local math3d_stack = math3d.new()

canvas = iup.canvas{}

local input_queue = inputmgr.queue(mapiup)
eu.regitster_iup(input_queue, canvas)

dlg = iup.dialog {
  canvas,
  title = "hello terrain world",
  size = "HALFxHALF",
}

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

-- math3d_stack 的错误，会引发不可预料的nuklear seq 错误，应该时lua 栈被破坏
-- 测试发现，需要注意
local function joystick_update()
	local move_dir = { x=0,y=0 }
	local rot_dir = { x =0,y=0 }

	nk.setStyle( skinStyle )   								
	if nk.windowBegin( "MoveJoy","ABC", 20, ctx.height-joy_width, joy_width, joy_width,"border" ) then 
		nk.layoutSpaceBegin("static",-1,-1);
		nk.joystick("movejoy",joy_rc,joy_size,radius,move_dir,joy_base,joy_image)						
	end
	nk.windowEnd()
	if nk.windowBegin( "RotJoy","ABC", ctx.width-joy_width-20, ctx.height-joy_width, joy_width, joy_width,"border" ) then 
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

local function process_input()
	local message = {}
	for _, msg,x,y,z,w,u in pairs(input_queue) do
		nkmsg.push(message, msg, x,y,z,w,u)
	end

	local useJoy = false 
	local use_rJoy = false 
	local dirx,diry,r_dirx,r_diry = joystick_update()

	if dirx ~= 0 or diry ~= 0 then
		 useJoy = true 
	end   
	if r_dirx ~= 0 or r_diry ~= 0 then 
		use_rJoy = true
	end 

	-- for rotation 
	if use_rJoy == true then 
		print("r_dir:",r_diry,r_dirx)
	  	dir[1]  = dir[1] + r_diry*3.5;
		dir[2]  = dir[2] + r_dirx*3.5;
		if(dir[1]>89) then dir[1] = 89 end 
		if(dir[1]<-89) then dir[1] = -89 end 
		print("dir:",dir[1],dir[2])
	end
	-- for movement 
	if useJoy == true then 
		-- local var feature
		local direction = utilmath.dir(dir[2],dir[1]) 
		local right = utilmath.side(dir[2],dir[1])
		view[1] = view[1] + right[1]*-dirx + direction[1]* -diry
		view[2] = view[2] + 0
		view[3] = view[3] + right[3]*-dirx + direction[3]* -diry
	end 

	local x = 0
	local y = 0 
	for i=1, #message do 
		local m = message[i]
		if m[1] == 'b' and m[3] == true then   									-- b,[l|m|r],press,x,y
			pressed = m[3]
			last_x  = m[4]
			last_y  = m[5]
		elseif m[1] == 'b' and m[3] == false  then          					-- btn release
			pressed = m[3]
			last_x  = m[4]
			last_y  = m[5]
		elseif m[1] == 'm' and pressed == true and useJoy == false   then  		-- m,x,y  for rotation 
			x = m[2]
			y = m[3] 
			local x_delta = x - last_x 
			local y_delta = y - last_y 
			dir[1] = dir[1] + y_delta*0.17    				
			dir[2] = dir[2] + x_delta*0.17
			last_x = x 
			last_y = y 
		elseif m[1] == 'k'  then --and m[3] == true then
			local direction = {}
			if m[2] == 'W' then 
				utilmath.direction(direction,dir[2],dir[1]) 	
				view[1] = view[1] + direction[1]
				view[2] = view[2] + direction[2]
				view[3] = view[3] + direction[3]
			elseif m[2] == 'S' then 
				utilmath.direction(direction,dir[2],dir[1]) 	
				view[1] = view[1] - direction[1]
				view[2] = view[2] - direction[2]
				view[3] = view[3] - direction[3]
			end 
			if m[2] == 'A' then
				direction = utilmath.side(dir[2],dir[1]) 	
				view[1] = view[1] + direction[1]
				view[2] = view[2] + direction[2]
				view[3] = view[3] + direction[3]
			elseif m[2] == 'D' then 
				direction = utilmath.side(dir[2],dir[1]) 	
				view[1] = view[1] - direction[1]
				view[2] = view[2] - direction[2]
				view[3] = view[3] - direction[3]
			end 

			if m[2] == 'F' then 
				fly = true 
			elseif m[2] == 'G' then 
				fly = false 
			elseif m[2] == 'F1' and m[3] == true then
				ctx.debug = not ctx.debug
				bgfx.set_debug( ctx.debug and "S" or "")
			elseif m[2] == 'F2' and m[3] ==true  then
				if prim_type == nil then prim_type = "LINES"
				elseif prim_type ~= nil then prim_type = nil end 
			elseif m[2] == 'F3' and m[3] == true then 
				if show_mode == 0 then show_mode = 1 
				elseif  show_mode == 1 then show_mode = 0 end 
				terrain:set_uniform("u_showMode", show_mode )
			end 

			if m[2] == 'period' then
				lightIntensity[1] = lightIntensity[1] +0.02
				terrain:set_uniform("u_lightIntensity", lightIntensity )
			elseif m[2] == 'comma' then 
				lightIntensity[1] = lightIntensity[1] -0.02
				terrain:set_uniform("u_lightIntensity",lightIntensity )
			end 

			if m[2] == "UP" then 
				lightColor[1]  = lightColor[1] + 0.02
			    terrain:set_uniform("u_lightColor", lightColor )
			elseif m[2] == "DOWN" then 
				lightColor[1]  = lightColor[1] - 0.02
				terrain:set_uniform("u_lightColor", lightColor )
			end 

			if m[2] == "LEFT" then
				lightColor[2]  = lightColor[2] + 0.02
			    terrain:set_uniform("u_lightColor", lightColor )
			elseif m[2] == "RIGHT" then 
				lightColor[2]  = lightColor[2] - 0.02
			    terrain:set_uniform("u_lightColor", lightColor )
			end 

			if m[2] == "minus" then
				lightColor[4] = lightColor[4] -0.02
				terrain:set_uniform("u_lightColor", lightColor )
			elseif m[2] == "equal" then 
				lightColor[4] = lightColor[4] +0.02
				terrain:set_uniform("u_lightColor", lightColor )
			end 

		end  
	end

	nk.input(message)
end 



local function mainloop()

	-- -- input
	process_input()

	
	-- control camera 
	local result,height = terrain:get_height( view[1],view[3] )
	if result == true and fly == false then 
		view[2] = height + 5  
	end 
	--print("view = ",view[1],view[2],view[3])
	--result,height = terrain_chibi:get_height( view[1],view[3] )
	--if result == true and fly == false then 
	--	view[2] = height + 5  
	--end 

	-- do camera viewproject
	local srt = { t= view or {0,130,-10,1},
	              r= dir or {25,45,0,0},
	 			  s= {1,1,1,1} }          								 -- for terrain ,eye,target
	-- local srt = { t= {0,30,-10,1}, r={0,45,0,0}, s= {1,1,1,1} }       -- yaw = 45, pitch = 25
	local proj_mtx = math3d_stack( { type = "proj",n=0.1, f = 1000, fov = 60, aspect = ctx.width/ctx.height } , "m")  
	local view_mtx = math3d_stack( srt.t,srt.r,"dLm" )    			     -- math3d_statck( op data 1,2,..,"op code string")

	bgfx.set_view_clear(0, "CD", 0x103030ff, 1, 0)
	bgfx.set_view_rect(0, 0, 0, ctx.width, ctx.height )
	bgfx.reset( ctx.width,ctx.height, "vmx")
	bgfx.touch(0)

	bgfx.set_view_transform(0,view_mtx,proj_mtx)

    -- terrain chibi 
	terrain_chibi:render( ctx.width,ctx.height)
    -- terrain pvp 
	terrain:update( view ,dir)                        -- for further anything 
	terrain:render( ctx.width,ctx.height,prim_type)   --"POINT","LINES"  -- for debug 

    ---[[
	bgfx_logo()
	--]]           
	-- ui input --
	local ortho_mtx = math3d_stack( { type = "ortho", l = 0, r = ctx.width, b = ctx.height, t = 0, n = 0, f = 100, h = false }, "m")  
	--local ortho_mtx = math3d_stack( { 2.0/ctx.width, 0.0, 0.0, 0.0,   0.0,-2.0/ctx.height, 0.0, 0.0,  0.0, 0.0,-1.0, 0.0,  -1.0, 1.0, 0.0, 1.0}, "m") 

	bgfx.set_view_transform(UI_VIEW,nil,ortho_mtx)	



	nk.update()
	
	
	bgfx.frame()
end

function bgfx_logo()
	bgfx.dbg_text_clear()
	bgfx.dbg_text_image(math.max(ctx.width //2//8 , 20)-20
				, math.max(ctx.height//2//16, 6)-6
				, 40
				, 12
				, s_logo
				, 160
				)

	bgfx.dbg_text_print(0, 1, 0xf, "Color can be changed with ANSI \x1b[9;me\x1b[10;ms\x1b[11;mc\x1b[12;ma\x1b[13;mp\x1b[14;me\x1b[0m code too.");
	local stats = bgfx.get_stats("sd",ctx.stats)

	bgfx.dbg_text_print(0, 2, 0x0f, string.format("Backbuffer %dW x %dH in pixels, debug text %dW x %dH in characters."
				, stats.width
				, stats.height
				, stats.textWidth
				, stats.textHeight
                ))
end 

local function init(canvas, fbw, fbh)

	rhwi.init(iup.GetAttributeData(canvas,"HWND"), fbw, fbh)
	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)
	bgfx.set_debug "T"

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

	print("nk init ok")
	
	local program_create_mode = 0

	---[[
	-- load terrain level 
	terrain:load("assets/build/terrain/pvp1.lvl", 
					{
						{ "POSITION", 3, "FLOAT" },
						{ "TEXCOORD0", 2, "FLOAT" },
						{ "TEXCOORD1", 2, "FLOAT" },
						{ "NORMAL", 3, "FLOAT" },
					}
				)
	--]]
	 terrain_chibi:load("assets/build/terrain/chibi16.lvl")

	if program_create_mode == 1 then 
		-- load from mtl setting 
		terrain:load_meterial("assets/build/terrain/terrain.mtl")
	else 
		-- or create manually
		terrain:load_program("terrain/vs_terrain.sc","terrain/fs_terrain.sc")
		terrain:create_uniform("u_mask","s_maskTexture","i1",1)
		terrain:create_uniform("u_base","s_baseTexture","i1",0)
		terrain:create_uniform("u_lightIntensity","s_lightIntensity","v4")
		terrain:create_uniform("u_lightColor","s_lightColor","v4")
		terrain:create_uniform("u_showMode","s_showMode","i1")   -- 0 default,1 = normal

		-- 初始值必须填写,这个限制有益? 或可以修改 terrain.lua 让 uniform 的初始值可以不填写
		terrain:set_uniform("u_lightIntensity",{1.316,0,0,0} )  
		terrain:set_uniform("u_lightColor",{1,1,1,0.625} )
		terrain:set_uniform("u_showMode",0)  
	end 

	terrain_chibi:load_meterial("assets/build/terrain/terrain.mtl")
	-- 手工增加调试，临时增加，可以放在关卡文件里
	terrain_chibi:create_uniform("u_showMode","s_showMode","i1")   -- 0 default,1 = normal
	terrain_chibi:set_uniform("u_showMode",0)   				   

	--terrain_chibi:set_transform { t= {-320,-30,-320,1},r= {0,0,0},s={1,1,1,1}}
	terrain_chibi:set_transform { t= {0,150,0,1},r= {0,0,0},s={1,1,1,1}}

	-- ui init
	joystick_init()

	task.loop(mainloop)
end

function canvas:resize_cb(w,h)
	if init then
		init(self, w, h)
		init = nil
	else 
		nk.resize(w,h)
	end
	bgfx.set_view_rect(0, 0, 0, w, h)
	bgfx.reset(w,h, "v")
	ctx.width = w
	ctx.height = h
end

-- function canvas:keypress_cb(key, press)
-- 	if key ==  iup.K_F1 and press == 1 then
-- 		ctx.debug = not ctx.debug
-- 		bgfx.set_debug( ctx.debug and "S" or "")
-- 	end
-- 	if key == iup.K_F12 and press == 1 then
-- 		bgfx.request_screenshot()
-- 	end
-- end


function canvas:action(x,y)
	mainloop()
end

dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil

-- to be able to run this script inside another context
if (iup.MainLoopLevel()==0) then
	iup.MainLoop()
	iup.Close()
end
