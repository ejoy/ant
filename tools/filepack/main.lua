package.path = "/engine/?.lua"
require "bootstrap"

dofile "/engine/task/bootstrap.lua" {
    bootstrap = { "p|main", arg },
    exclusive = { "timer", "subprocess" },
}
