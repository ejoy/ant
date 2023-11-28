package.path = "/engine/?.lua"
require "bootstrap"

local task = dofile "/engine/task/bootstrap.lua"
task {
    bootstrap = { "imgui|boot" },
    logger = { "logger" },
    exclusive =  { "timer", "subprocess" },
}
