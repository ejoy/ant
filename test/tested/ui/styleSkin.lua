local nk = require "bgfx.nuklear"
local atlas = require "tested.ui.atlas"

-- skin Style 
local skin = {
    ['button'] = {
       -- ['normal'] = 0,
       -- ['hover']  = 0,
       -- ['active'] = 0,
    },
}

local atlas_skin = { }

local init = false;
-- single,atlas 
return function ( image ,aimage )
    if not init then
      skin.button['normal'] = image.button.n
      skin.button.hover = image.button.h 
      skin.button.active = image.button.c 
      skin.button['text normal'] = '#000000'
      skin.button['text hover']  = '#00ffff'
      skin.button['text active'] = '#ffffff'
      skin.button['text alignment'] = 'centered'
      print("init once")
      init = true
      atlas_skin = atlas( aimage )
    end 
    ---[[
    ui_header("单个位图按钮")
    nk.setFont(2)
    nk.setStyle( skin ) 
    nk.layoutRow('static',52,{100,100,100,100,100,100} )
    nk.spacing(2)
    nk.button("image1")
    nk.button("image2")
    nk.spacing(1)
    nk.button("ok")
    nk.unsetStyle( skin )
    --]] 
    ---[[
    ui_header("图集位图按钮")    
    nk.setFont(1)
    nk.setStyle( atlas_skin ) 
    nk.layoutRow('dynamic',60,{0.25,0.25,0.25,0.25} )
    nk.spacing(1)
    nk.button("image1")
    nk.button("image2")
    --]]
    nk.layoutRow("static",300,{100,600,100})
    -- left area
    nk.spacing(1)
    if nk.areaBegin("皮肤Demo ","title","border","movable","scrollbar") then
        nk.layoutRow("dynamic",30,{0.7,0.3} )
        local c = '#ffaa00'
        for i=1,20,1 do 
            if (i%2) ==1 then 
               c= '#00aaff'
            else
               c= '#ffaa00' 
            end  
            nk.label("context description .."..i.." {...}","left",c)
            nk.button("ok")
        end 
        nk.areaEnd()
    end    
    nk.unsetStyle( atlas_skin )
end 


