package.path = "/engine/?.lua"
require "bootstrap"

dofile "/engine/ltask.lua" {
    bootstrap = { "p|main", arg },
    exclusive = { "timer", "subprocess" },
}
