local nk = require "bgfx.nuklear"
local atlas = require "tested.ui.atlas"

-- skin Style 
local skin = {  ['button'] = { },['window']={} }

local off = 0
local scl = 1
local d   = 1
local rc  = { x=340,y=60,w=340,h=140 }

local rc1 = { x=340,y=60,w=140,h=140 }
local rc2 = { x=340,y=160,w=140,h=140 }
local rc3 = { x=340,y=320,w=140,h=140 }


local init = false;

return function( nkimage )
     if not init then
        skin.button['normal'] = nkimage.button.n
        skin.button.hover     = nkimage.button.h 
        skin.button.active    = nkimage.button.c 
        skin.button['text normal'] = '#000000'
        skin.button['text hover']  = '#00ffff'
        skin.button['text active'] = '#ffffff'
        skin.button['text alignment'] = 'centered'
        skin.window['background'] = '#00FF0000'
        -- 风格化屏蔽窗口背景，group 对齐边框
        --skin.window['fixed background'] = '#FF000000'
        --skin.window['group padding'] = {x=0,y=0 }
        print("init once")
        init = true
    end 
    
     -- 任意位置，交互修改
     -- 开始自由布局，不管区域宽高
     nk.layoutSpaceBegin("static",-1,-1);
     nk.setFont(2)
     nk.irrbutton("irrbutton",rc,nkimage.button.n);
     nk.layoutRow("dynamic",20,1)
     nk.button("button",nkimage.button.n);
     nk.layoutSpaceEnd()

    ---[[
    ui_header("不规则按钮")
    -- 透明图
	nk.setFont(1)
    nk.layoutRow('static',128,{128,200,128} )
    nk.setStyle(skin)
    -- . .. .
    nk.button(" ")          
    nk.button(" ")   
    nk.button(" ")  

    -- 任意位置及大小
    nk.layoutSpaceBegin("static",500,-1);
    -- .  .
    --  .
    nk.layoutSpacePos(60, 10,120,120);
    nk.button(" ");
    nk.layoutSpacePos(200,100,120,120);
    nk.button(" ");
    nk.layoutSpacePos(340,10,140,140);
    nk.button(" ");

    -- 任意位置，交互修改
    nk.setFont(2)
    -- 风格影响下的 irrbutton
    if nk.irrbutton("irrbutton",rc1) then 
       print("irrbutton1 ok")
    end 
    if nk.irrbutton("irrbutton",rc2) then 
        print("irrbutton2 ok")
    end 
    if nk.irrbutton("irrbutton",rc3) then 
        print("irrbutton2 ok")
    end 
    --print( "rc 1 = ("..rc1.x..","..rc1.y..","..rc1.w..","..rc1.h..")" )

    -- 缩放移动部分
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
    -- 这部分移动控制，形成控件，可以尝试用 lua 做一个 ui toolset，ui control 
    nk.layoutSpacePos( 400+off*scl-120*scale*0.5,128+64-120*scale*0.5  ,120*scale,120*scale );
    nk.button(" ");
    nk.layoutSpacePos( 400+off*scl-120*0.5 ,128+64-120*0.5,120,120);
    nk.button(" ");
    
    nk.layoutSpaceEnd()

    nk.unsetStyle()      
    --]] 
end
