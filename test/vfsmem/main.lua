package.path = "/engine/?.lua"
require "bootstrap"

dofile "/engine/task/bootstrap.lua" {
    bootstrap = { "test|main" },
    exclusive =  { "timer" },
}
