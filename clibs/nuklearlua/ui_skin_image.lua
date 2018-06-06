local nk = require 'nuklearlua'
local string = require "string"

local check_sel = {
    value = true
}

local windowHeader = nk.loadImage("skin/window_header.png")
font_msyh_idx = nk.loadFont("font/msyh.ttf",16)

local quadSkinStyle = 
{
	['window'] = {
		['header'] = {
			['normal'] = windowHeader, -- '#d3ce0a', --
			['hover']  = windowHeader, -- '#d3ceaa', --
			['active'] = windowHeader, -- '#d3ceaa', -- 
			['label normal'] = '#000000',
			['label hover'] =  '#00ff00',
			['label active'] = '#0000ff',
			['label padding'] = {x = 10, y = 8}
		},
		['fixed background'] = nk.loadImage 'skin/window.png',  --'#d3ce0a', -- 
		['background'] = '#d3ce0a'
	},
	['button'] = {
		['text normal'] = "#0000ff",
		['text hover'] = "#ff00ff",
		['text active'] = "#00ffff",

	},
}

-- 3 draw calls single image, 1 draw calls only
--   window,label,button, diff color only one draw call
--   仅仅是 skin header，window 需要3个 draw calls ？？？ 独立图片
return function()
	nk.setFont( font_msyh_idx )
    nk.setStyle( quadSkinStyle )

	if nk.windowBegin("Quad Image Window Sample",800,500,400,200, 'title',"movable") then
		nk.layoutRow('dynamic',30,1)
		nk.button("image button")
		nk.button("微软雅黑")
		nk.button(nil,"#ffaacc")
		nk.layoutRow('dynamic',30,3)
		nk.spacing(1)
		nk.button("ok")
	end 
    nk.windowEnd()
	nk.unsetStyle()
	nk.setFont(0)
end 