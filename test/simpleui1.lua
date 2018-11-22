dofile "libs/init.lua"
package.path = package.path..';../clibs/terrain/?.lua;./clibs/terrain/?.lua;' 
package.cpath = package.cpath..';../clibs/terrain/?.dll;./clibs/terrain/?.dll;'


local bgfx = require "bgfx"
local rhwi = require "render.hardware_interface"
local sm = require "render.resources.shader_mgr"
local task = require "editor.task"
local nk = require "bgfx.nuklear"
local inputmgr = require "inputmgr"
local mapiup = require "editor.input.mapiup"
local nkmsg = require "inputmgr.nuklear"

local loadfile = require "tested.loadfile"
local ch_charset = require "tested.charset_chinese_range"

local label = require "tested.ui.label"
local button = require "tested.ui.button"
local widget = require "tested.ui.widget"
local image = require "tested.ui.image"
local edit = require "tested.ui.edit"
local progress = require "tested.ui.progress"
local slider = require "tested.ui.slider"
local checkbox = require "tested.ui.checkbox"
local combobox = require "tested.ui.combobox"
local radio = require "tested.ui.radio"
local property = require "tested.ui.property"
local colorStyle = require "tested.ui.styleColors"
local skinStyle = require "tested.ui.styleSkin"
local area = require "tested.ui.areaWindow"
local irr_btn = require "tested.ui.buttonIrregular"
local joystick = require "tested.ui.joystick"

local terrainClass = require "terrain"
local texLoad = require "utiltexture"
local eu = require "editor.util"

local terrain = terrainClass.new()       -- new terrain instance 

local canvas = iup.canvas {}

local miandlg = iup.dialog {
	canvas,
	title = "simple terrain",
	size = "HALFxHALF",
}

local input_queue = inputmgr.queue(mapiup)
eu.regitster_iup(input_queue, canvas)

local UI_VIEW = 0


local nkatlas = {}
local nkbtn = {}
local nkimage = {} 
local nkb_images = { button = {} }
local ir_images = { button = {} }

local joy_image = {}
local joy_base = {}
local joy_attack = { button= {} } 

local function save_ppm(filename, data, width, height, pitch)
	local f = assert(io.open(filename, "wb"))
	f:write(string.format("P3\n%d %d\n255\n",width, height))
	local line = 0
	for i = 0, height-1 do
		for j = 0, width-1 do
			local r,g,b,a = string.unpack("BBBB",data,i*pitch+j*4+1)
			f:write(r," ",g," ",b," ")
			line = line + 1
			if line > 8 then
				f:write "\n"
				line = 0
			end
		end
	end
	f:close()
end


function save_screenshot(filename)
	local name , width, height, pitch, data = bgfx.get_screenshot()
	if name then
		local size = #data
		if size < width * height * 4 then
			-- not RGBA
			return
		end
		print("Save screenshot to ", filename)
		save_ppm(filename, data, width, height, pitch)
	end
end



local ctx = {}
local message = {}

local btn_func = {
	LABEL    = 1,  BUTTON = 2, IMAGE = 3,    WIDGET = 4,   EDIT = 5,
	PROGRESS = 6,  SLIDER = 7, CHECKBOX = 8, COMBOBOX = 9, PROPERTY = 10, 
	RADIO =11,     SKIN = 12,  AREA = 13,    IRREGULAR=14, JOYSTICK = 15,
}

local btn_ac = 0

-- 透明窗口的创建方法：
-- 1. 使用颜色，这样内部按钮也不能使用 image Skin，作为普通风格可行
-- 2. 使用imageSkin 在atlas 位图上设计 fixed background 的透明位图，做 hud 时方便使用 

local skinStyle = {
    ['window'] = {
       ['background'] = '#00000000',
       ['fixed background'] = "#00000000",
    },
}

local function nk_samples()
	nk.setFont(1)
	nk.setStyle( skinStyle )
	--if nk.windowBegin( "Test","Test Window 汉字 ui 特性展示", 0, 0, 720, 460,
	--				   "border", "movable", "title", "scalable",'scrollbar') then 
	if nk.windowBegin( "Test","", 100, 100, 720, 500,
					   "movable" ) then 

		-- layout row 1
		nk.layoutRow('static',30,{120,120,32,140,120,140} ) 
		nk.setFont(2)
		if nk.button("label","triangle left") then
			btn_ac  = btn_func.LABEL 
		end 
		if nk.button( "button","triangle right" ) then
			btn_ac = btn_func.BUTTON 
		end 
		--image 
		if nk.button(nil, nk.subImage(nkbtn,0,0,69,52)   ) then 
			btn_ac = btn_func.IMAGE 
		end 
		if nk.button( "widget") then 
			btn_ac = btn_func.WIDGET			
		end 
		if nk.button("edit",nk.subImageId(nkbtn.handle,nkbtn.w,nkbtn.h,0,0,69,52)) then
			btn_ac = btn_func.EDIT 
		end 
		if nk.button("progress","rect solid") then
			btn_ac = btn_func.PROGRESS
		end 

		-- layout row 2 
		nk.layoutRow('static',30,{120,120,32,140,140,120} )  
		if nk.button("slider","rect solid") then
			btn_ac = btn_func.SLIDER
		end 
		if nk.button("radio","circle solid") then
			btn_ac = btn_func.RADIO 
		end 
		if nk.button("o","circle outline") then
			nk.defaultStyle()
		end 
		if nk.button("checkbox","rect outline") then
			btn_ac = btn_func.CHECKBOX 
		end 
		if nk.button("combobox","triangle down") then
			btn_ac = btn_func.COMBOBOX
		end 
		if nk.button("property","plus") then 
			btn_ac = btn_func.PROPERTY 
		end 

		---- layout row 3
		nk.layoutRow("dynamic",32,{0.05,0.05,0.05,0.05,0.05,0.18,0.18,0.1,0.1}) 
		if nk.button(nil,"#ff0000") then
			nk.themeStyle("theme red")
		end 
		if nk.button(nil,"#00ff00") then
			colorStyle()
		end 
		if nk.button(nil,"#0000ff") then
			nk.themeStyle("theme blue")
		end 
		if nk.button(nil,"#ffffff") then
			nk.themeStyle("theme white")
		end 
		if nk.button(nil,"#1d1d1d") then
			nk.themeStyle("theme dark")
		end 

		if nk.button("skinning","plus") then 
			btn_ac = btn_func.SKIN
		end 
		if nk.button("area","plus") then 
			btn_ac = btn_func.AREA
		end 
		if nk.button("irrbtn") then
			btn_ac = btn_func.IRREGULAR
		end 
		if nk.button("joystick")  then 
			btn_ac = btn_func.JOYSTICK
		end 
		
		-- nk.layoutRow('dynamic',30,{1/6,1/6,1/6,1/6,1/6,1/6} )
		-- nk.layoutRow("dynamic",30,1)
		-- print("---id("..nkimage.handle..")"..' w'..nkimage.w..' h'..nkimage.h)

		-- do action 
		if btn_ac == btn_func.LABEL  then 
			label() 
		elseif btn_ac == btn_func.BUTTON then
			button( nkbtn )
		elseif btn_ac == btn_func.IMAGE then 
			image( nkimage )
		elseif btn_ac == btn_func.WIDGET then
			widget( nkbtn )
		elseif btn_ac == btn_func.EDIT then
			edit()
		elseif btn_ac == btn_func.PROGRESS then
			progress()
		elseif btn_ac == btn_func.SLIDER then
			slider()
		elseif btn_ac == btn_func.CHECKBOX then
			checkbox()
		elseif btn_ac == btn_func.COMBOBOX then
			combobox()
		elseif btn_ac == btn_func.RADIO then
			radio()
		elseif btn_ac == btn_func.PROPERTY then
			property()
		elseif btn_ac == btn_func.SKIN then
			skinStyle(nkb_images,nkatlas )
		elseif btn_ac == btn_func.AREA then
			area(nkbtn)
		elseif btn_ac == btn_func.IRREGULAR then
			irr_btn( ir_images )
		elseif btn_ac == btn_func.JOYSTICK then
			joystick( joy_image,joy_base,joy_attack )
		end 
	end 

	nk.windowEnd()	
	nk.unsetStyle()
end 

local function mainloop()

	--save_screenshot "screenshot.ppm"
	for _, msg,x,y,z,w,u in pairs(input_queue) do
		nkmsg.push(message, msg, x,y,z,w,u)
	end
	nk.input(message)
 
	nk_samples();
	
	nk.update()

	terrain:render(ctx.width,ctx.height,"LINES")
	
	bgfx.dbg_text_clear()
	bgfx.dbg_text_print(0, 1, 0xf, "Color can be changed with ANSI \x1b[9;me\x1b[10;ms\x1b[11;mc\x1b[12;ma\x1b[13;mp\x1b[14;me\x1b[0m code too.");


	bgfx.frame()
end

function loadfonts(font,size,charset)
	print("charset length ="..#charset[2])
	return loadfile(font),size,charset
end 

--staging ,not finished
function loadatlas(texname,cfg)
	atlas.id = loadimage(texname)
	atlas.name = texname
	for _,v in pairs(cfg) do
		atlas[v] = { name,x,x,w,h }
	end 
end 
-- 从 nkimage 按 atlas 找到 subimage 
function subimage(name,nkimage,atlas)
	local si = atlas[ name ]
	print(si.id,si.w,si.h,si.x0,si.y0,si.x1,si.y1)
end 
--staging end 

function loadtexture(texname,info)
	--local f = assert(io.open(texname, "rb"))
	--local imgdata = f:read "a"
	--f:close()
	--local imgdata = loadfile(texname)
	--local h = bgfx.create_texture(imgdata, "ucvc")  -- 支持dds,pvr,? 三种格式
	--bgfx.set_name(h, texname)

	local image = nk.loadImage( texname );			  -- nk有自己的 image rect 需求,so
	--bgfx.set_name(image.handle,texname)    		  -- TEXTURE<<16|image.handle 

	return image
end 

function loadTestedTextures()
	-- tested load images 	
	-- nkb_images.n =
	nkb_images.button.n =  loadtexture("assets/build/textures/button.png")
	nkb_images.button.h =  loadtexture("assets/build/textures/button_hover.png")
	nkb_images.button.c =  loadtexture("assets/build/textures/button_active.png")
	--irregular button 
	ir_images.button.n = loadtexture("assets/build/textures/irbtn_normal.png")
	ir_images.button.h = loadtexture("assets/build/textures/irbtn_hover.png")
	ir_images.button.c = loadtexture("assets/build/textures/irbtn_active.png")

	-- 单张图
	joy_image = loadtexture("assets/build/textures/yaogan.tga")
	joy_base  = loadtexture("assets/build/textures/yaogandi.tga")
    -- 三张状态图
	joy_attack.button.n = loadtexture("assets/build/textures/pugong.tga")
	joy_attack.button.h = loadtexture("assets/build/textures/pugong.tga")
	joy_attack.button.c = loadtexture("assets/build/textures/pugong_ac.tga")
	-- image tools tested
	local raw_data = nk.loadImageData("assets/build/textures/gwen.png");  -- return raw data
	-- makeImage from memory
	nkatlas = nk.loadImageFromMemory(raw_data.data,raw_data.w,raw_data.h,raw_data.c)
	-- return image directly
	nkatlas = loadtexture( "assets/build/textures/terrain_mask_texture.png"); --gwen.png") 
	nkimage = nk.makeImage( nkatlas.handle,nkatlas.w,nkatlas.h)  		  -- make from outside id ,w,h 
	nkbtn   = loadtexture( "assets/build/textures/button_active.png" )
    -- tested load images	
end

local function init(canvas, fbw, fbh)

	rhwi.init( iup.GetAttributeData(canvas,"HWND"), fbw, fbh)
  
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
		prog = sm.programLoad("ui/vs_nuklear_texture.sc","ui/fs_nuklear_texture.sc"),

		fonts = {
			{ "宋体行楷", loadfonts("build/fonts/stxingka.ttf",50, ch_charset()  ), },
			{ "微软雅黑", loadfonts("build/fonts/stxingka.ttf",20, ch_charset() ), },
		},

	}

	-- tested load images for all controls
	loadTestedTextures()
	
	-- terrain 部分正确使用详见 helloterrain.lua :)
	terrain:load("assets/build/terrain/pvp1.lvl")
	terrain:load_program("terrain/vs_terrain.sc","terrain/fs_terrain.sc")

	bgfx.set_view_clear(UI_VIEW, "C", 0x303030ff, 1, 0)

	task.loop(mainloop)
end

function canvas:resize_cb(w,h)
	if init then
		init(self, w, h)
		init = nil
	else
		nk.resize(w,h)
	end
	bgfx.reset(w,h, "v")
	ctx.width = w
	ctx.height = h
end

function canvas:action(x,y)
	mainloop()
end

function canvas:keypress_cb(key, press)
	if key ==  iup.K_F1 and press == 1 then
		ctx.debug = not ctx.debug
		bgfx.set_debug( ctx.debug and "S" or "")
	end
	if key == iup.K_F12 and press == 1 then
		bgfx.request_screenshot()
	end
end


miandlg:showxy(iup.CENTER,iup.CENTER)
miandlg.usersize = nil

iup.MainLoop()
iup.Close()
