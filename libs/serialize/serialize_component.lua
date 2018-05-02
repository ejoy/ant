local ecs = ...

ecs.component "serialize" {
    uuid = ""
}

ecs.component "serialize_intermediate_format" {
    tree = {type="userdata", }
}