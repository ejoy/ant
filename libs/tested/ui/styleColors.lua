local nk = require "bgfx.nuklear"

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

return function ()
    nk.colorStyle( colors ) 
end 
