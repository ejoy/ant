package.path = "/engine/?.lua"
require "bootstrap"
local task = dofile "/engine/task/bootstrap.lua"
task {
    bootstrap = { "p|main", arg },
    logger = { "logger" },
    exclusive = { "timer", "subprocess" },
    debuglog = "server_log.txt",
}
