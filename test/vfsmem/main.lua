package.path = "/engine/?.lua"
require "bootstrap"

local task = dofile "/engine/task/bootstrap.lua"
task {
    bootstrap = { "test|main" },
    logger = { "logger" },
    exclusive =  { "timer" },
}

