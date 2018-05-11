
--package.cpath='d:/work/task/nuklearlua/?.dll'
local nk = require 'nuklearlua'
local string = require 'string'

nk.setWindow {} 
nk.init()    -- ? 

local skin_atlas_image = require 'skin_atlas'
local skin_single_image = require 'skin_image'
local editor = require "editor"


-- style setting
--[[
local style = {
	['text'] = {
		['color'] = '#000000'
	},
	['button'] = {
		['normal'] = loadImage 'skin/button.png',
		['hover'] =  loadImage 'skin/button_hover.png',
		['active'] = loadImage 'skin/button_active.png',
		['text background'] = '#00000000',
		['text normal'] = '#000000',
		['text hover']  = '#000000',
		['text active'] = '#ffffff'
	},
	['checkbox'] = {
		['normal'] = checkboxSkin,
		['hover'] = checkboxSkin,
		['active'] = checkboxSkin,
		['cursor normal'] = checkboxCheck,
		['cursor hover'] = checkboxCheck,
		['text normal'] = '#000000',
		['text hover'] = '#000000',
		['text active'] = '#000000',
		['text background'] = '#d3ceaa'
	},
	['window'] = {
		['header'] = {
			['normal'] = windowHeader,
			['hover'] = windowHeader,
			['active'] = windowHeader,
			['label normal'] = '#000000',
			['label hover'] = '#000000',
			['label active'] = '#000000',
			['label padding'] = {x = 10, y = 8}
		},
		['fixed background'] = love.graphics.newImage 'skin/window.png',
		['background'] = '#d3ceaa'
	}
}
]]

-- init 
nk.checkVersion()


-- only color table list
local colors = {
    ['text'] = '#afffff', 
	['window'] = '#999999',
	['header'] = '#282828',
	['border'] = '#414141',
	['button'] = '#afafaf', 
	['button hover'] = '#282828',
	['button active'] = '#0000ff', --'#232323',
	['toggle'] = '#646464',
	['toggle hover'] = '#787878',
	['toggle cursor'] = '#2d2d2d',
	['select'] = '#2d2d2d',
	['select active'] = '#232323',
	['slider'] = '#262626',
	['slider cursor'] = '#646464',
	['slider cursor hover'] = '#787878',
	['slider cursor active'] = '#969696',
	['property'] = '#262626',
	['edit'] = '#262626',
	['edit cursor'] = '#afafaf',
	['combo'] = '#2d2d2d',
	['chart'] = '#787878',
	['chart color'] = '#2d2d2d',
	['chart color highlight'] = '#ff0000',
	['scrollbar'] = '#282828',
	['scrollbar cursor'] = '#646464',
	['scrollbar cursor hover'] = '#787878',
	['scrollbar cursor active'] = '#009696',
	['tab header'] = '#282828'
}

-- struct nk_image { handle,w,h,x0,y0,x1,y1 }
local image = nk.loadImage 'skin/button.png'
-- image & color style setting，table tree node 
local skinStyle = {
    ['window'] = {
       -- ['header']     = '#0000ff', 		-- nk.loadImage("skin/window_header.png"),
       -- ['background'] = '#00ffff',
       -- ['fixed background'] = "#00dddd"  -- winskin,
    },
    ['button'] = {
		--['normal'] =  nk.checkVersion(),  -- save function 
		--['normal'] = "#0000aa",  		    -- nk.loadImage 'skin/button.png',
		['normal'] =  nk.loadImage("skin/button.png"),
        ['hover']  =  nk.loadImage("skin/button_hover.png"),  --"#FF0000",
		--['hover']  =  nk.subImageId( image.handle,image.w,image.h,10,10,42,40),  --"#FF0000",
		['active'] =  nk.loadImage("skin/button_active.png"), --"#00FF00",
        --['active'] =  nk.subImage( image,0,0,32,32 ),        
        ['text background'] = '#00000000',
        ['text normal'] = '#000000',
        ['text hover']  = '#000000',
        ['text active'] = '#ffffff',
    },
}


-- ui control vars
local edit = { value = 'edit box mode: \n test test test in pane'} 
local dlg_edit = { value = 'edit editor mode: text in dlg window'}

local check_edit = {value = false}
local check_cut  = {value = false}
local check_copy = {value = false}
local check_add  = true

local slide_value = 50
local progress_value = { value = 50}
local combo = {value = 3, items = {'A item', 'B item', 'C item'}}

local radio_c = {value = 'item a'}
local radio_n = {value = 'item 3'}

local property_value = { value = 6 }


-- ui create 
--SCREEN_WIDTH  = 1200
--SCREEN_HEIGHT = 800
local function update()
	--do nothing          			-- system default
    --nk.styleDefault();  			-- mydefault 
    --nk.styleTheme("theme_dark") 	-- theme
    nk.colorStyle( colors )

	 
	  
    ---[[
	nk.frameBegin()
		--Window Styles
		-- "border", "movable", "scalable", "closable","minimizable","scrollbar","title","scroll auto hide","background"

		-- name,x,y,width,height,style1,style2，....
        nk.windowBegin("Demo",0,800-100,1200,100,"border","title")
	        --nk.layoutRow("dynamic",30,1);
		nk.windowEnd()

  
		nk.setStyle( skinStyle )
	 
		-- draw call = 1 + 6*2 = 13 ,single image effect 
		nk.windowBegin("Demo 1",1200-375,80,350,440,"border","title","movable")
			--nk.layoutRow("dynamic",30,1);
			nk.layoutRow('dynamic', 120, 2)
			nk.button( "A"  ) 
			nk.button( "B"  ) 
			nk.button( "C"  ) 
			nk.button( "D"  ) 
			nk.button( "E"  ) 
			nk.button( "F"  ) 
		nk.windowEnd()
	 
		nk.unsetStyle()

		-- "name","title",x,y,width,height,"border","title" window flags etc 
		nk.windowBegin("Pane",0,0,200,800-100,"border","title",'scrollbar')
			nk.layoutRow('dynamic', 18, 1)
			-- "name"
			-- align = "left","right","centered","top left","top centered","top right","bottom left”,"bottom centered","bottom_right"
			-- color = "#FF0000"
			-- name,align,color
			-- name 
			---[[  1 draw call
			nk.label("Hello,Workspace!")
			nk.label('First Line !',"left")
			nk.label('Second Line !',"centered")
			nk.label( "Third Line !", "right","#FF0000")
		 

			-- button
			-- name
			-- name, "symbol"
			-- name, image 
			-- nil,  "#00ffff"   -- 颜色按钮不提供 title
			-- name, "underscore“
			-- name, image     -- 未提供
			-- 对齐使用全局设置,或应该再提供一个参数 ? 或提供一个 static 固定定位
			-- (name|nil), (symbol|image|color)
			--   1 draw call
			nk.button( "button"  ) 
			nk.button( "button","triangle down" )
			nk.button( "button","circle solid" )
			nk.button( "button","underscore" )
			nk.layoutRow('dynamic', 14, 2)
			nk.button( "button", "plus" )
			nk.button( "button", "minus")
			if nk.button( nil, "#ffff00" ) then
				print('----- yellow color ---')
			end 
			if nk.button( nil, "#ff0000" ) then 
				print('----  red color ----')
			end 	
			nk.layoutRow('dynamic', 18, 1)
			if(nk.button( "button" )) then
			print('============Button!=========')
			end 
			 
			-- edit 
			---  1 draw call
			nk.layoutRow('dynamic', 40, 1)
			local text, changed = nk.edit('edit box',edit)
			if changed then
				print( text )
			else
			    --print( "no changed ".. text ) 
			end 
			 

			-- checkbox
			---   1 draw call
			nk.layoutRow('dynamic',20,4)
			nk.checkbox("edit",check_edit)
			nk.checkbox("cut",check_cut)
			nk.checkbox("copy",check_copy)
			check_add = nk.checkbox("add",check_add)
			-- 
			-- slider 
			---   1 draw call
			nk.layoutRow('dynamic',20,2)
			nk.label("slider","left","#ff0000")
			slide_value = nk.slider(slide_value,0,100,1)
			-- 
			-- progress 
			---  0 draw call combine with slider 
			nk.layoutRow('dynamic',20,1)
			nk.label("progress","centered","#00ff00")
			nk.progress(progress_value,100,true)
			-- 
			-- combobox
			--  1 draw call,extend 2 draw call
			nk.label("combobox","right","#0000ff")
			nk.combobox(combo,combo.items)
			-- 

			-- radio 
			---  -- 0 draw call
			nk.layoutRow('dynamic',20,3)
			nk.radio("item a",radio_c)
			nk.radio("item b",radio_c)
			nk.radio("item c",radio_c)

			nk.layoutRow('dynamic',20,3)
			nk.spacing(3);
			--nk.layoutRow('dynamic',20,3)
			nk.radio("item 1",radio_n)
			nk.radio("item 2",radio_n)
			nk.radio("item 3",radio_n)
			nk.radio("item 1",radio_n)
			nk.radio("item 2",radio_n)
			nk.radio("item 3",radio_n)

			for idx=1,3,1 do 
				nk.radio("item 1",radio_n)
				nk.radio("item 2",radio_n)
				nk.radio("item 3",radio_n)
			end 

			for idx=1,12,1 do 
				nk.radio("item"..string.format("%02d",idx),radio_n) 
			end 
			-- 
			-- property
			---  1 draw call 
			nk.layoutRow('dynamic',20,1)
			nk.property('Property', property_value,0, 100, 0.5, 0.05)
			-- 
		nk.windowEnd()

		-- 7 draw calls all above elements 

		-- skn window
		-- 7 draw calls 
		skin_atlas_image()

		-- quad image skin window
		-- 4 draw calls single image, 
		-- 1 draw calls only colors
		skin_single_image()

		editor()
        
    nk.frameEnd()
	--]]
end

-- setup ui main loop update
nk.setUpdate( function()
                 local ok,err = xpcall( update,debug.traceback) 
                 if not ok then
                    print(err)
                 end 
                 return 
              end 
            )

-- run 
nk.mainloop()

-- shutdown
nk.shutdown()

