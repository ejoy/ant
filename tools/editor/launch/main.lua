package.path = "/engine/?.lua"
require "bootstrap"

local task = dofile "/engine/task/bootstrap.lua"
task {
    bootstrap = { "launch|boot" },
    logger = { "logger" },
    exclusive =  { "timer", "subprocess" },
}
