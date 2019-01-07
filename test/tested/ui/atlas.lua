local nk = require "bgfx.nuklear"
-- 风格表使用样例，未来应该提供 atlas texture 工具,自动化生成的这种风格配置表
local atlas = {
    ['window'] = {
        ['header'] = { },
        --['background'],
        --['fixed background'],
    },

    ['button'] = { },
    ['scrollv'] = {
        ['inc button'] = {},
        ['dec button'] = {},
       -- ['show buttons'] = 1，
     },
    --[[
    ['checkbox'] = { },
    ['slider'] = { },
    ['progress']= { },
    ['combobox'] = { },
    ['radio'] = { },
    ['property'] = {
        ["inc button"] = { },
        ["dec button"] = { },        
        ["edit"] = { },
    },

    ["edit"] =  { },

    ['combobox'] = { 
        ["button"] = {  },        
    }
    ]]
}

local init = false;

return function ( image )
    if not init then
      atlas.window.header.normal = nk.subImage( image,128,0,127,24 )
      atlas.window.header.hover = nk.subImage( image,128,0,127,24) 
      atlas.window.header.active = nk.subImage( image,128,0,127,24)
      atlas.window.header['label normal'] = '#000000'
      atlas.window.header['label hover']  = '#ffff00'
      atlas.window.header['label active'] = '#ffffff'
      atlas.window['scrollbar size'] = {x=16,y=16}
      atlas.window['background'] = '#7f7f7f'
      --atlas.window['fixed background'] = '#00000000'
      atlas.window['fixed background'] = nk.subImage( image,128,23,127,104)
      atlas.window['border'] = 1
      atlas.window['border color'] = '#2d2d2d'
      atlas.window.header['text background'] = '#00000000'
      atlas.window['padding'] = {x=-12,y=4}

      atlas.button.normal = nk.subImage( image,384,336,127,31)
      atlas.button.hover = nk.subImage( image,384,368,127,31) 
      atlas.button.active = nk.subImage( image,384,400,127,31) 
      atlas.button['text normal'] = '#000000'
      atlas.button['text hover']  = '#aa00aa'
      atlas.button['text active'] = '#ffffff'
      atlas.button["image padding"] = {x=0,y=0}
	  atlas.button["touch padding"] = {x=1,y=1}

      atlas.scrollv['inc button'].normal =  nk.subImage( image, 464,256,15,15)
      atlas.scrollv['inc button'].hover =  nk.subImage( image, 464,320,15,15)
      atlas.scrollv['inc button'].active =  nk.subImage( image, 464,320,15,15)
      atlas.scrollv['inc button'].border = 50

      atlas.scrollv['dec button'].normal =  nk.subImage( image, 464,224,15,15 )
      atlas.scrollv['dec button'].hover = nk.subImage( image,464,288,15,15)
      atlas.scrollv['dec button'].active = nk.subImage( image,464,288,15,15)
      atlas.scrollv['dec button'].border = 60

      atlas.scrollv['border cursor'] = 1
      atlas.scrollv['rounding cursor'] = 2
      atlas.scrollv['border'] = 1
      atlas.scrollv['border color'] = '#515151'
      atlas.scrollv['rounding'] = 0
    
      atlas.scrollv['normal']   = '#B8B8B8'
      atlas.scrollv['hover']    = '#B8B8B8'
      atlas.scrollv['active']   = '#B8B8B8'


      atlas.scrollv['cursor normal']   = '#DCDCDC'
      atlas.scrollv['cursor hover']    = '#EAEAEA'
      atlas.scrollv['cursor active']   = '#63CAFF'
      
      print("init atlas once")
      init = true
    end 
    return atlas;
end 


