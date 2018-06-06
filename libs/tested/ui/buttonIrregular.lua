local nk = require "bgfx.nuklear"
local atlas = require "tested.ui.atlas"

-- skin Style 
local skin = {  ['button'] = { }, }

local off = 0
local scl = 1
local d = 1
return function( nkimage )
     if not init then
        skin.button['normal'] = nkimage.button.n
        skin.button.hover = nkimage.button.h 
        skin.button.active = nkimage.button.c 
        skin.button['text normal'] = '#000000'
        skin.button['text hover']  = '#00ffff'
        skin.button['text active'] = '#ffffff'
        skin.button['text alignment'] = 'centered'
        print("init once")
        init = true
    end     
    ---[[
	ui_header("不规则按钮")
	nk.setFont(1)
    nk.layoutRow('static',128,{128,200,128} )
    nk.setStyle(skin)
    nk.button(" ")          
    nk.button(" ")   
    nk.button(" ")  
    nk.layoutSpaceBegin("static",500,-1);
    nk.layoutSpacePos(60,10,120,120);
    nk.button(" ");
    nk.layoutSpacePos(200,100,120,120);
    nk.button(" ");
    nk.layoutSpacePos(340,10,120,120);
    nk.button(" ");

    if d == 1 then 
        off = off + 1
    elseif d==-1 then 
        off = off - 1
    end 

    if off <= -200 then
        d = 1
    elseif off>= 200 then 
        d = -1;
    end 

    local scale = 1
    
    if off >0  then 
        scale = (off)/60*scl 
    elseif off< 0 then 
        scale = (-off)/60*scl 
    else  
       scale = 1/60*scl
    end 
     
    nk.layoutSpacePos( 400+off*scl-120*scale*0.5,128+64-120*scale*0.5  ,120*scale,120*scale );
    nk.button(" ");
    nk.layoutSpacePos( 400+off*scl-120*0.5 ,128+64-120*0.5,120,120);
    nk.button(" ");
    print("x= "..200 +off*scl)

    
    nk.layoutSpaceEnd()
    nk.unsetStyle()      
    --]] 
end
