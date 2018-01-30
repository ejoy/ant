local ecs = ...

--{@
local math3d = require "math3d"
local math3d_comp = ecs.component "math3d"

function math3d_comp.new()    
	return math3d.new()
end
--@}

function check_comp_creation(comp, errMsg)
    if comp == nil then
        error(errMsg)
    end
end

local camera_transform = ecs.component "view_transform" {

}

check_comp_creation(camera_transform)


local camera_frustum = ecs.component "frustum" {

}

check_comp_creation(camera_frustum)






