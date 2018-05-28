
--package.cpath='d:/work/task/nuklearlua/?.dll'
local nk = require 'nuklearlua'
local string = require 'string'

--nk.setWindow {} 
nk.init()    -- ? 

local editor = require "ui_editor"
local skin_atlas_image = require 'ui_skin_atlas'
local skin_single_image = require 'ui_skin_image'
local left_pane = require "ui_leftpane"

-- only color table list
local colors = {
    ['text'] = '#afffff', 
	['window'] = '#999999',
	['header'] = '#282828',
	['border'] = '#414141',
	['button'] = '#afafaf', 
	['button hover'] = '#282828',
	['button active'] = '#0000ff',
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

---[[
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
		--['normal'] = "#0000aa",  		    -- nk.loadImage 'skin/button.png',
		['normal'] =  nk.loadImage("skin/button.png"),
        ['hover']  =  nk.loadImage("skin/button_hover.png"),  --"#FF0000",
		--['hover']  =  nk.subImageId( image.handle,image.w,image.h,10,10,42,40),  --"#FF0000",
		['active'] =  nk.loadImage("skin/button_active.png"), --"#00FF00",
        ['text background'] = '#00000000',
        ['text normal'] = '#000000',
        ['text hover']  = '#000000',
        ['text active'] = '#ffffff',
		['rounding'] = 10,
		
    },
}

local function update()
	--do nothing          			-- system default
    --nk.styleDefault();  			-- mydefault 
    --nk.styleTheme("theme_dark") 	-- theme
    nk.colorStyle( colors )         -- custum color
	 
	left_pane()  
	-- 7 draw calls all above elements 
	-- skn window
	-- 7 draw calls 
	skin_atlas_image()

	-- quad image skin window
	-- 4 draw calls single image, 
	-- 1 draw calls only colors
	skin_single_image()

	editor()	
	
	--nk.frameBegin()
		--Window Styles
		-- "border", "movable", "scalable", "closable","minimizable","scrollbar","title","scroll auto hide","background"

		-- name,x,y,width,height,style1,style2，....
		nk.windowBegin("Demo",0,800-100,1200,100,"border","title")
	        --nk.layoutRow("dynamic",30,1);
		nk.windowEnd()

  
		nk.setStyle( skinStyle )     -- image skin
	 
		-- draw call = 1 + 6*2 = 13 ,single image effect 
		if nk.windowBegin("Demo 1",1200-375,80,350,440,"border","title","movable") then 
			nk.layoutRow('dynamic', 120, 2)
			nk.button( "A"  ) 
			nk.button( "B"  ) 
			nk.button( "C"  ) 
			nk.button( "D"  ) 
			nk.button( "E"  ) 
			nk.button( "F"  ) 
		end 
		nk.windowEnd()
	 
		nk.unsetStyle()
        
    --nk.frameEnd()

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

