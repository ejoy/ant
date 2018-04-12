local ecs = ...
ecs.component "position"{
    v = {type="vector"}
}

ecs.component "rotation"{
    v = {type="vector"}
}

ecs.component "scale" {
    v = {type="vector"}
}

ecs.component "frustum" {
    isortho = false,
    n = 0.1,
    f = 10000,
    l = -1,
    r = 1,
    t = -1,
    b = 1,
}

ecs.component "viewid"{
    id = 0
}

ecs.component "render" {
    info = {type = "userdata", ""},
    visible = true,
}

ecs.component "name" {
    n = ""
}

ecs.component "can_select" {

}

ecs.component "last_render"{
    enable = true
}

ecs.component "control_state" {
    state = "camera"
}

