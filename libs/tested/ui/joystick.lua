local nk = require "bgfx.nuklear"
local atlas = require "tested.ui.atlas"  -- coule be generate by tool
local string = require "string"
-- skin Style 
local skin = {  ['button'] = { },['window']={} }

local off = 0
local scl = 1
local d   = 1

-- movable irrbutton
local rc  =  { x=340,y=60,w=340,h=140 }

-- joystick pos & size
local rc_joystick  = { x= 120,y=180,w=200,h=200 }
local radius = 0.9  --rc_joystick.w/2*0.9
local joystick_size = 0.7 
-- action pos & size 
local rc_attack    = { x= 720,y=70,w=80,h=80 }
local rc_attack1   = { x= 720,y=150,w=80,h=80 }
local rc_attack2   = { x= 615,y=185,w=80,h=80 }
local rc_attack3   = { x= 570,y=285,w=80,h=80 }
local rc_sword     = { x= 690,y=260,w=110,h=110 }

-- return value 
local dir    = { x=0,y=0 }  --joystick 
local action = "attack"     --which action button hit

local init = false 
return function( im_joy,im_base,im_attack )
     if not init then
        skin.button['normal'] = im_attack.button.n 
        skin.button.hover     = im_attack.button.h  
        skin.button.active    = im_attack.button.c  
        skin.button['text normal'] = '#000000'
        skin.button['text hover']  = '#00ffff'
        skin.button['text active'] = '#ffffff'
        skin.button['text alignment'] = 'centered'
        --skin.window['background'] = '#00FF0000'
        --skin.window['fixed background'] = '#FF000000'
        --skin.window['group padding'] = {x=0,y=0 }
        print("init once")
        init = true
    end 
    
    -- 任意位置，交互修改
    -- free space begin
    nk.layoutSpaceBegin("static",-1,-1);

    nk.setFont(2)
    nk.irrbutton("irrbutton",rc,im_joy);

    -- 没有风格皮肤设置时，外部image 作为button 装饰，文字右对齐
    if nk.irrbutton("no style",rc_attack,im_joy,"movable") then
        action = "attack1"
    end


    nk.joystick("joy",rc_joystick,joystick_size,radius,dir,im_base,im_joy)

    nk.setStyle(skin)
    -- extend image & style,movable button 
    -- 使用风格皮肤，文字居中，在传入外部image 则覆盖，最表层图片
    if nk.irrbutton("attack ",rc_attack1,"movable") then
        action = "attack1"
    end
    if nk.irrbutton(" ",rc_attack2) then
        action = "attack2"
    end 
    if nk.irrbutton(" ",rc_attack3) then
        action = "attack3"
    end
    if nk.irrbutton(" ",rc_sword)  then
        action = "sword"
    end    
    nk.unsetStyle()

    -- free space end 
    nk.layoutSpaceEnd()

    rc.x = rc.x + dir.x;
    rc.y = rc.y + dir.y;
    
    ui_header("虚拟游戏杆")
    nk.setFont(2)
    nk.layoutRow("dynamic",30,{0.5,0.5})
    local xs = string.format("%0.2f",dir.x)
    local ys = string.format("%0.2f",dir.y)
    nk.label("joystick direction :".." X= "..xs.." Y= "..ys)
    nk.label("actiion : "..action)

    nk.setStyle(skin)
    nk.unsetStyle()      
    
end
