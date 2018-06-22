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

ecs.component "directional_light"
ecs.component "point_light"
ecs.component "spot_light"
ecs.component "ambient_light"

ecs.component "light" {
	v = {
		type = "userdata",
		default = {
			type = "point", 	-- "spot", "directional", "ambient"
			intensity = 50, 
			color = {1, 1, 1, 1},
			rot = {0, 0, 0}, 
			pos = {0, 0, 0}, 
			angle = 360,
			range = 100,
		},

		save = function(v, arg)		
			return v
		end,
	
		load = function(v, arg)
			return v
		end
	},
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
