local ecs = ...

-- local function check_light_array(l)
-- 	local directional_light_num = 0
-- 	for _, lt in ipairs(l) do
-- 		if lt.type == "directional" then
-- 			directional_light_num = directional_light_num + 1
-- 		end
-- 	end

-- 	if directional_light_num > 1 then
-- 		return false, "too many directional light"
-- 	end

-- 	return true, nil
-- end

ecs.tag "directional_light"
ecs.tag "point_light"
ecs.tag "spot_light"
--ecs.component_struct "ambient_light" {    -- add tested 
-- 	type = "userdatar",   			 
-- 	mode = "color", 				-- or factor, gradient, skybox etc
-- 	factor = 0.3,     			    -- use direction light's factor directioncolor *factor 
-- 	color = {1, 1, 1, 1},
-- 	gradient = { 
-- 		skycolor = {1,1,1,1},
-- 		midcolor = {1,1,1,1},
-- 		groundcolor = {1,1,1,1},
-- 	},
--}

ecs.component "light" {
	type = "userdata",
	default = {
		type = "point", 	-- "spot", "directional", "ambient"
		intensity = 50, 
		color = {1, 1, 1, 1},
		angle = 360,
		range = 100,
	},

	save = function(v, arg)		
		return v
	end,

	load = function(v, arg)
		return v
	end
}



-- local light_system = ecs.system "light_system"

-- function light_system:init()
-- 	local succ, msg = check_light_array(self.light.lights)
-- 	if not succ then
-- 		print(msg)
-- 	end
-- end

-- function light_system:update()

-- end
