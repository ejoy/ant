local ecs = ...
ecs.component "position"{
    v = {type="vector"}
}

ecs.component "direction"{
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
    binding = {type="userdata", ""},
    mesh = {type="asset", ""},

    visible = true,
}



