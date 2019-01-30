local ecs = ...
local world = ecs.world

-- combine and set into system path 
-- package.path = package.path..';./libs/terrain/?.lua;'
-- package.path = package.path..';./libs/bullet/?.lua;'
-- local bullet_world = require "bulletworld"

ecs.import "ant.inputmgr"
local timer = import_package "ant.timer"
local bgfx = require "bgfx"
local camera_util = import_package "ant.render".util
local mathu = (import_package "ant.math").util
local stack = (import_package "ant.math").stack

local char_controller_sys = ecs.system "charcontroller_system"
char_controller_sys.singleton "message"

char_controller_sys.depend "message_system"
char_controller_sys.depend "camera_init"  -- new use mode 

local VIEW_DEBUG_DRAWER = 255

local step = 0.2

local print_r = function(name,x,y,z)
    print(name..": ", string.format("%08.4f",x), string.format("%08.4f",y), string.format("%08.4f",z) )
end 
local function sqrt2(a,b)
    return (a[1]-b[1])*(a[1]-b[1]) + (a[2]-b[2])*(a[2]-b[2]) + (a[3]-b[3])*(a[3]-b[3])
end 

local action_type = { 
	FORWARD = false, BACKWARD = false,
	LEFT = false, RIGHT = false,
	UPWARD = false, DOWNWARD = false,
	LEFTROT = false, RIGHTROT = false,
	ROTX = false, ROTY = false
}

local function register_input_message(self)
    --[[
    --local ms = self.math_stack
    local ms = stack 

    local camera = world:first_entity("main_camera")

    local math = import_package "ant.math"
    local point2d = math.point2d

	local move_speed = 1
	local message = {}

    local last_xy
	local button_status = {}
	-- luacheck: ignore self
	-- luacheck: ignore status
    function message:button(btn, p, x, y, status)
        button_status[btn] = p
        last_xy = point2d(x, y)
	end

	function message:motion(x, y, status)
		local xy = point2d(x, y)
		if last_xy then
			if status.RIGHT then
				local speed = move_speed * 0.1
				local delta = (xy - last_xy) * speed	
				camera_util.rotate(ms, camera, delta.x, delta.y)
			end 
		end

		last_xy = xy
	end

	local action_name_mappers = {
		-- right button
		r_a = "LEFT", r_d = "RIGHT",
		r_w = "FORWARD", r_s = "BACKWARD",
		r_c = "DOWNWARD", r_f = "UPWARD",		
		r_q = "LEFTROT", r_e = "RIGHTROT",
	}

	function message:keypress(c, p, status)
		if c == nil then return end

		local name = nil
		if button_status.RIGHT then
			name = 'r_'
		elseif button_status.LEFT then
			name = 'l_'
		end

		local clower = c:lower()
		if name then
			name = name .. clower
			local t = action_name_mappers[name]
			if t then
				action_type[t] = p
			end	
		end

		if clower == "cequal" then
			step = math.min(1, step + 0.002)
		elseif clower == "cminus" then
			step = math.max(0.002, step - 0.002)
		end			
	end

    self.message.observers:add(message) 
    --]]
    local math = import_package "ant.math"
    local point2d = math.point2d

    local camera = world:first_entity("main_camera")

	local move_speed = 1
	local message = {}

    local last_xy
	local button_status = {}
	-- luacheck: ignore self
	-- luacheck: ignore status
    function message:mouse_click(btn, p, x, y, status)
        button_status[btn] = p
        last_xy = point2d(x, y)
	end

	function message:mouse_move(x, y, status)
		local xy = point2d(x, y)
		if last_xy then
			if status.RIGHT then
				local speed = move_speed * 0.1
				local delta = (xy - last_xy) * speed	--we need to reverse the drag direction so that to rotate angle can reverse
				camera_util.rotate(camera, delta.x, delta.y)
			end 
		end

		last_xy = xy
	end

	local action_name_mappers = {
		-- right button
		r_a = "LEFT", r_d = "RIGHT",
		r_w = "FORWARD", r_s = "BACKWARD",
		r_c = "DOWNWARD", r_f = "UPWARD",		
		r_q = "LEFTROT", r_e = "RIGHTROT",
	}

	function message:keyboard(c, p, status)
		if c == nil then return end

		local name = nil
		if button_status.RIGHT then
			name = 'r_'
		elseif button_status.LEFT then
			name = 'l_'
		end

		local clower = c:lower()
		if name then
			name = name .. clower
			local t = action_name_mappers[name]
			if t then
				action_type[t] = p
			end	
		end

		local isctrl = status.CTRL
		if isctrl then
			if clower == "=" then
				step = math.min(1, step + 0.002)
			elseif clower == "-" then
				step = math.max(0.002, step - 0.002)				
			end	
		end		
	end

	self.message.observers:add(message)

end 

local function move_step(camera, pos, deltaTime, ms ,Physics )
  
    local dx, dy, dz = 0, 0, 0
    if action_type.FORWARD then 
        dz = step
    elseif action_type.BACKWARD then
        dz = -step
    end

    if action_type.LEFT then 
        dx = -step			
    elseif action_type.RIGHT then 
        dx = step
    end

    if action_type.UPWARD then
        dy = step
    elseif action_type.DOWNWARD then
        dy = -step
    end

    if action_type.LEFTROT then 
        camera_util.rotate(ms, camera, -step * deltaTime , 0)
    elseif action_type.RIGHTROT then 
        camera_util.rotate(ms, camera,  step * deltaTime, 0)
    end 

    local pxdir, pydir, pzdir = ms(camera.rotation, "bPPP")
    local xdir = ms(pxdir,"T")
    local ydir = ms(pydir,"T")
    local zdir = ms(pzdir,"T")

    local walk_direction = ms(ms(camera.rotation,"dP"),"T")
    walk_direction[2] = 0 

    local move_flags = false 
    local walk_dir = {0,0,0}
    if dz > 0 or dz < 0 then
        local move_delta = dz
        walk_dir[1] = walk_dir[1] + zdir[1]*move_delta*deltaTime
        walk_dir[2] = 0 -- walk_dir[2] + zdir[2]*move_delta*deltaTime
        walk_dir[3] = walk_dir[3] + zdir[3]*move_delta*deltaTime
        move_flags = true
    end 
    if dx > 0 or dx < 0 then 
        local move_delta = dx 
        walk_dir[1] = walk_dir[1] + xdir[1]*move_delta*deltaTime
        walk_dir[2] = 0 --walk_dir[2] + xdir[2]*move_step*deltaTime
        walk_dir[3] = walk_dir[3] + xdir[3]*move_delta*deltaTime
        move_flags = true
    end 
    if dy > 0 or dy < 0 then
        local move_delta = dy 
        walk_dir[1] = 0
        walk_dir[2] = walk_dir[2] + ydir[2]*move_delta*deltaTime
        walk_dir[3] = 0
        move_flags = true
    end 

    local walk_to = {0,0,0}
    walk_to[1] = pos[1]+ walk_dir[1]*1000
    walk_to[2] = pos[2]+ walk_dir[2]*1000
    walk_to[3] = pos[3]+ walk_dir[3]*1000

    local rs = { pos[1],pos[2]-0.05,pos[3]}
    local rt = { walk_to[1],walk_to[2],walk_to[3]}
    Physics:drawline(rs,rt,0xff0000ff)


    local len = 10 r = 4 
    local walk_step = 1
    local hit, result = Physics:raycast(pos, walk_to)
    -- local hit = false 
    if hit  then 
        local ent = world[result.useridx]
        print("---")  -- sometimes ,ent already delete ,but no delete object from physics sync
        if ent then 
            if ent.terrain then print("hit terrain",ent.name.n, result.useridx) end 
            if ent.mesh then print("hit mesh",ent.name.n,result.useridx)  end 
        else
            print("ent = nil, entity delete but shape exist") 
        end  
        print_r("forward dir hit = ",result.hit_pt_in_WS[1],result.hit_pt_in_WS[2],result.hit_pt_in_WS[3])
        walk_step = result.hit_fraction
        len = sqrt2(pos,result.hit_pt_in_WS) 
    end  

    -- walk_step snap 
    if move_flags and len> r then 
        if deltaTime > 16 then deltaTime = 16 end 
        pos[1] = pos[1] + walk_dir[1]*deltaTime*0.01 
        pos[2] = pos[2] + walk_dir[2]*deltaTime*0.01 
        pos[3] = pos[3] + walk_dir[3]*deltaTime*0.01
    end 
    ms(camera.position,pos,'=') 
end     
local function step_up()
    -- todo: 
end 
local function slide()
    -- todo:
end 
local function jump()
   -- todo:
end 
local function on_ground( camera,pos, deltaTime,ms, Physics )
    local ray_s = { pos[1], pos[2]+1, pos[3]}  
    local ray_e = { pos[1], pos[2]-1000,pos[3]} 
    local hit, result = Physics:raycast(ray_s, ray_e)
    if  hit  then 
        pos[2] = result.hit_pt_in_WS[2] + 4
        ms(camera.position,pos,'=')
    end 
end 

local function ray_stress( Physics )
    local ray_s = { 0, 1000, 0 }
    local ray_e = { 0, -1000, 0 }
    local rand = math.random
    for i=-20 , 35 do 
        for j=-20 , 35 do 
            local r = rand()
            ray_s[1] = i*2*r  ray_s[2] =  520  ray_s[3] = j*2*r
            ray_e[1] = i*2*r  ray_e[2] = -520  ray_e[3] = j*2*r

            Physics:drawline(ray_s,ray_e,0xaaaaaa00)
            local hit, result= Physics:raycast(ray_s, ray_e)
            -- if  hit == false  then 
            --     print("hit noting",i,j)
            -- end  
        end
    end
end 


function char_controller_sys:init()
    local Physics = world.args.Physics
    if Physics == nil then return end 

    Physics:set_debug_drawer("on",bgfx)

    register_input_message(self)
   --[[ 
    local math = import_package "ant.math"
    local point2d = math.point2d

    local camera = world:first_entity("main_camera")

	local move_speed = 1
	local message = {}

    local last_xy
	local button_status = {}
	-- luacheck: ignore self
	-- luacheck: ignore status
    function message:mouse_click(btn, p, x, y, status)
        button_status[btn] = p
        last_xy = point2d(x, y)
	end

	function message:mouse_move(x, y, status)
		local xy = point2d(x, y)
		if last_xy then
			if status.RIGHT then
				local speed = move_speed * 0.1
				local delta = (xy - last_xy) * speed	--we need to reverse the drag direction so that to rotate angle can reverse
				camera_util.rotate(camera, delta.x, delta.y)
			end 
		end

		last_xy = xy
	end

	local action_name_mappers = {
		-- right button
		r_a = "LEFT", r_d = "RIGHT",
		r_w = "FORWARD", r_s = "BACKWARD",
		r_c = "DOWNWARD", r_f = "UPWARD",		
		r_q = "LEFTROT", r_e = "RIGHTROT",
	}

	function message:keyboard(c, p, status)
		if c == nil then return end

		local name = nil
		if button_status.RIGHT then
			name = 'r_'
		elseif button_status.LEFT then
			name = 'l_'
		end

		local clower = c:lower()
		if name then
			name = name .. clower
			local t = action_name_mappers[name]
			if t then
				action_type[t] = p
			end	
		end

		local isctrl = status.CTRL
		if isctrl then
			if clower == "=" then
				step = math.min(1, step + 0.002)
			elseif clower == "-" then
				step = math.max(0.002, step - 0.002)				
			end	
		end		
	end

	self.message.observers:add(message)
    --]]

end     

local del_flag = true 
local frames = 0
--local function recyle_test(world)
    -- gc debug test, fast recyle 
    -- package.path = package.path..';./clibs/terrain/?.lua;./test/?.lua;'
    -- package.path = package.path..';./clibs/bullet/?.lua;'
    -- local bullet_world = require "bulletworld"
  
    -- if  world.args.Physics and del_flag then 
    --     world.args.Physics:delete()
    --     world.args.Physics = nil 
    --     del_flag = false
    -- else 
    --    frames = frames +1 
    --    if frames <= 2 then return end 
    --    frames = 0
    --    if world.args.Physics then world.args.Physics:delete()   end 
    --    world.args.Physics = bullet_world.new()
    -- end 
    -- or bullet_world.clear()
--end 

function char_controller_sys:update()
    -- recyle_test(world)
    
    local Physics = world.args.Physics
    if Physics == nil then  return  end 

    --Physics:set_debug_drawer("off")
    --Physics:set_debug_drawer("on")

    local fb = world.args.fb_size
    --local ms = self.math_stack 
    local ms = stack 

    -- raycast 
    local camera = world:first_entity("main_camera")
    local pos = ms(camera.position,"T")

    local deltaTime =  timer.deltatime
    -- print("deltaTime",deltaTime)
    move_step( camera, pos, deltaTime, ms, Physics )

    on_ground( camera, pos, deltaTime, ms, Physics )

    ray_stress( Physics )

    Physics:debug_draw_world( VIEW_DEBUG_DRAWER, world, ms, mathu,fb )
    collectgarbage("step")   -- put this to end_frame_system or the end of a frame logic 
end





