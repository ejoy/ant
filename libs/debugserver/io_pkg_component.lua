local ecs = ...

local io_pkg_component = ecs.component "io_pkg_component" {
    recv_pkg = {type = "userdata"},
    send_pkg = {type = "userdata"},
}