package.path = "/engine/?.lua"
require "bootstrap"

dofile "/engine/task/bootstrap.lua" {
    bootstrap = { "tools.material_compile|init", arg },
    exclusive = { "timer", "subprocess" },
}
