local ecs = ...

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






