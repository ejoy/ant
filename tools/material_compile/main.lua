package.path = "/engine/?.lua"
require "bootstrap"

dofile "/engine/ltask.lua" {
    bootstrap = { "tools.material_compile|init", arg },
    exclusive = { "timer", "subprocess" },
}
