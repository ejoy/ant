local ecs = ...

local camera_transform = ecs.component "view_transform" {
    eye = {type = "vector"},
    direction = {type = "vector"}
}

local camera_frustum = ecs.component "frustum" {
    projMat = {type = "matrix"}
}








