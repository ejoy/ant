local bgfx = require "bgfx"
local utilmath = require "utilmath"
local math3d = require "math3d"

local terrainClass = require "terrain"

local terrain = terrainClass.new()       	-- new terrain instance pvp
local terrain_chibi = terrainClass.new()    -- chibi

local math3d_stack = math3d.new()


local view = {200,12,200,1}
local dir = {0,0,0}

local fly = true
local ctx = { stats = {} }
local helloterrain = {}

local last_x = 0
local last_y = 0
local pressed = false

local lightIntensity = {1.316,0,0,0}
local lightColor = {1,1,1,0.625}
local show_mode = 0

--touches moved x: 191.500000, y: 420.500000

local function GetScreenTouchPos(log_string)
    local _, x_start = string.find(log_string, "x: ")
    local x_end = string.find(log_string, ", ")
    local x_pos = string.sub(log_string, x_start+1, x_end-1)

    local _, y_start = string.find(log_string, "y: ")
    local y_pos = string.sub(log_string, y_start+1)

    return x_pos, y_pos
end

local screen_width = 665
local screen_height = 365

local left_mid = {x = screen_width / 4, y = screen_height / 2}

local move_dir = {x = 0, y = 0}

function helloterrain.ProcessInput(...)
    local message = {}
    local log_string = ...

    --print(log_string)
    local x_pos, y_pos = GetScreenTouchPos(log_string)
    x_pos = tonumber(x_pos)
    y_pos = tonumber(y_pos)

    --print("last pos", x_pos, y_pos, screen_width / 2)
    local _, endpos = string.find(log_string, "moved")
    if endpos then
        --right side rotate
        if x_pos > screen_width / 2 then
            table.insert(message, {"m", x_pos, y_pos, true})
        else

        if x_pos < screen_width*0.5 then
            move_dir = {x = 0.01*(x_pos-left_mid.x), y = 0.01*(y_pos-left_mid.y)}
        end

        end
    else
        _, endpos = string.find(log_string, "began")
        if endpos then
            table.insert(message, {"b", "l", true, x_pos, y_pos})

            --print("begin", x_pos, y_pos)
            if x_pos > screen_width*0.8 and y_pos > screen_height*0.8 then
                table.insert(message, {"k", "F1", true})
            end

            if x_pos > screen_width*0.8 and y_pos < screen_height*0.2 then
                table.insert(message, {"k", "period", true})
            end

            if x_pos > screen_width*0.5*0.8 and x_pos < screen_width*0.5*1.2 and y_pos < screen_height *0.2 then
                table.insert(message, {"k", "comma", true})
            end

            if x_pos < screen_width*0.2 and y_pos > screen_height*0.8 then
                table.insert(message, {"k", "RIGHT", true})
            end

            if x_pos > screen_width*0.5*0.8 and x_pos < screen_width*0.5*1.2 and y_pos > screen_height *0.8 then
                table.insert(message, {"k", "LEFT", true})
            end

            if x_pos < screen_width*0.2 and y_pos < screen_height*0.2 then
                table.insert(message, {"k", "G", true})
            end

            if x_pos < screen_width*0.5 then
                move_dir = {x = 0.01*(x_pos-left_mid.x), y = 0.01*(y_pos-left_mid.y)}
            end

            if y_pos > screen_height*0.5*0.8 and y_pos < screen_height*0.5*1.2 and x_pos < screen_width *0.2 then
                table.insert(message, {"k", "minus", true})
            end

            if y_pos > screen_height*0.5*0.8 and y_pos < screen_height*0.5*1.2 and x_pos > screen_width *0.8 then
                table.insert(message, {"k", "equal", true})
            end


        else
            _, endpos = string.find(log_string, "end")
            if endpos then
                move_dir = {x = 0, y = 0}

                table.insert(message, {"b", "l", false, x_pos, y_pos})
            end
        end
    end


    local x = 0
    local y = 0
    for i=1, #message do
        local m = message[i]
        if m[1] == 'b' and m[3] == true then   				-- b,[l|m|r],press,x,y
            pressed = m[3]
            last_x  = m[4]
            last_y  = m[5]
        elseif m[1] == 'b' and m[3] == false  then          -- btn release
            pressed = m[3]
            last_x  = m[4]
            last_y  = m[5]
        elseif m[1] == 'm' and m[4] == true then  		-- m,x,y
            x = m[2]
            y = m[3]
            local x_delta = x - last_x
            local y_delta = y - last_y
            dir[1] = dir[1] + y_delta*0.17
            dir[2] = dir[2] + x_delta*0.17
            last_x = x
            last_y = y
        elseif m[1] == 'k'  then --and m[3] == true then
            local direction = {}
            if m[2] == 'W' then
                utilmath.direction(direction,dir[2],dir[1])
                view[1] = view[1] + direction[1]
                view[2] = view[2] + direction[2]
                view[3] = view[3] + direction[3]
            elseif m[2] == 'S' then
                utilmath.direction(direction,dir[2],dir[1])
                view[1] = view[1] - direction[1]
                view[2] = view[2] - direction[2]
                view[3] = view[3] - direction[3]
            end
            if m[2] == 'A' then
                direction = utilmath.side(dir[2],dir[1])
                view[1] = view[1] + direction[1]
                view[2] = view[2] + direction[2]
                view[3] = view[3] + direction[3]
            elseif m[2] == 'D' then
                direction = utilmath.side(dir[2],dir[1])
                view[1] = view[1] - direction[1]
                view[2] = view[2] - direction[2]
                view[3] = view[3] - direction[3]
            end

            if m[2] == 'F' then
                fly = true
            elseif m[2] == 'G' then
                if fly then
                    fly = false
                else
                    fly = true
                end

            elseif m[2] == 'F1' and m[3] == true then
                ctx.debug = not ctx.debug
                bgfx.set_debug( ctx.debug and "S" or "")
            elseif m[2] == 'F2' and m[3] ==true  then
                if prim_type == nil then prim_type = "LINES"
                elseif prim_type ~= nil then prim_type = nil end
            elseif m[2] == 'F3' and m[3] == true then
                if show_mode == 0 then show_mode = 1
                elseif  show_mode == 1 then show_mode = 0 end
                terrain:set_uniform("u_showMode", show_mode )
            end

            if m[2] == 'period' then
                lightIntensity[1] = lightIntensity[1] +0.2
                terrain:set_uniform("u_lightIntensity", lightIntensity )
            elseif m[2] == 'comma' then
                lightIntensity[1] = lightIntensity[1] -0.2
                terrain:set_uniform("u_lightIntensity",lightIntensity )
            end

            if m[2] == "UP" then
                lightColor[1]  = lightColor[1] + 0.2
                terrain:set_uniform("u_lightColor", lightColor )
            elseif m[2] == "DOWN" then
                lightColor[1]  = lightColor[1] - 0.2
                terrain:set_uniform("u_lightColor", lightColor )
            end

            if m[2] == "LEFT" then
                lightColor[2]  = lightColor[2] + 0.2
                terrain:set_uniform("u_lightColor", lightColor )
            elseif m[2] == "RIGHT" then
                lightColor[2]  = lightColor[2] - 0.2
                terrain:set_uniform("u_lightColor", lightColor )
            end

            if m[2] == "minus" then
                lightColor[4] = lightColor[4] -0.1
                terrain:set_uniform("u_lightColor", lightColor )
            elseif m[2] == "equal" then
                lightColor[4] = lightColor[4] +0.1
                terrain:set_uniform("u_lightColor", lightColor )
            end

        end
    end
end


function helloterrain.mainloop()
    -- input
    --process_input()
    ---[[
	-- control camera
    local direction = {}
    utilmath.direction(direction,dir[2],dir[1])
    --direction = utilmath.direction(dir[2],dir[1])
    view[1] = view[1] - move_dir.y*direction[1]
    view[2] = view[2] - move_dir.y*direction[2]
    view[3] = view[3] - move_dir.y*direction[3]

    direction = utilmath.side(dir[2],dir[1])
    view[1] = view[1] - move_dir.x*direction[1]
    view[2] = view[2] - move_dir.x*direction[2]
    view[3] = view[3] - move_dir.x*direction[3]


	local result,height = terrain:get_height( view[1],view[3] )
	if result == true and fly == false then 
		view[2] = height + 5  
	end
	--print("view = ",view[1],view[2],view[3])
	--result,height = terrain_chibi:get_height( view[1],view[3] )
	--if result == true and fly == false then 
	--	view[2] = height + 5  
	--end 

	-- do camera viewproject
	local srt = { t= view or {0,130,-10,1},
	              r= dir or {25,45,0,0},
	 			  s= {1,1,1,1} }          								 -- for terrain ,eye,target
	-- local srt = { t= {0,30,-10,1}, r={0,45,0,0}, s= {1,1,1,1} }       -- yaw = 45, pitch = 25
	local proj_mtx = math3d_stack( { type = "proj",n=0.1, f = 1000, fov = 60, aspect = ctx.width/ctx.height } , "m")  
	local view_mtx = math3d_stack( srt.t,srt.r,"dLm" )    			     -- math3d_statck( op data 1,2,..,"op code string")

	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)
	bgfx.set_view_rect(0, 0, 0, ctx.width, ctx.height )
	bgfx.reset( ctx.width,ctx.height, "vmx")
	--]]
	bgfx.touch(0)

	bgfx.set_view_transform(0,view_mtx,proj_mtx)

    -- terrain chibi
    --terrain_chibi:render( ctx.width,ctx.height)
    -- terrain pvp 
	terrain:update( view ,dir)                        -- for further anything
	terrain:render( ctx.width,ctx.height)   --"POINT","LINES"  -- for debug

    bgfx.frame()

    --]]
    --[[
    bgfx.touch(0)
    bgfx.dbg_text_clear()

    bgfx.dbg_text_print(0, 1, 0xf, "Color can be changed with ANSI \x1b[9;me\x1b[10;ms\x1b[11;mc\x1b[12;ma\x1b[13;mp\x1b[14;me\x1b[0m code too.");

    bgfx.frame()
    --]]
  --  print("yeseyysye")
end


function helloterrain.init(fbw, fbh, app_dir, bundle_dir)
    ctx.width = fbw
    ctx.height = fbh

	local program_create_mode = 0

    ---[[
	-- load terrain level
    terrain:load(app_dir.."/Client/assets/build/terrain/pvp1.lvl",
            {
                { "POSITION", 3, "FLOAT" },
                { "TEXCOORD0", 2, "FLOAT" },
                { "TEXCOORD1", 2, "FLOAT" },
                { "NORMAL", 3, "FLOAT" },
            }
    )


    if program_create_mode == 1 then
        -- load from mtl setting
        terrain:load_meterial(app_dir.."/Client/assets/build/terrain/terrain.mtl")
    else
        -- or create manually
        terrain:load_program("/terrain/vs_terrain","/terrain/fs_terrain")
        terrain:create_uniform("u_mask","s_maskTexture","i1",1)
        terrain:create_uniform("u_base","s_baseTexture","i1",0)
        terrain:create_uniform("u_lightIntensity","s_lightIntensity","v4")
        terrain:create_uniform("u_lightColor","s_lightColor","v4")
        terrain:create_uniform("u_showMode","s_showMode","i1")   -- 0 default,1 = normal

        -- 初始值必须填写,这个限制有益? 或可以修改 terrain.lua 让 uniform 的初始值可以不填写
        terrain:set_uniform("u_lightIntensity",{1.316,0,0,0} )
        terrain:set_uniform("u_lightColor",{1,1,1,0.625} )
        terrain:set_uniform("u_showMode",0)
    end
    --]]
---[[
    terrain_chibi:load(app_dir.."/Client/assets/build/terrain/chibi16.lvl")
    terrain_chibi:load_meterial(app_dir.."/Client/assets/build/terrain/terrain.mtl")
	terrain_chibi:create_uniform("u_showMode","s_showMode","i1")   -- 0 default,1 = normal
	terrain_chibi:set_uniform("u_showMode",0)   				   -- 手工增加可以放在文件里

	--terrain_chibi:set_transform { t= {-320,-30,-320,1},r= {0,0,0},s={1,1,1,1}}
	terrain_chibi:set_transform { t= {0,150,0,1},r= {0,0,0},s={1,1,1,1}}
	--]]
end

function helloterrain.terminate()

end

return helloterrain
