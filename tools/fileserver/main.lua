package.path = "/engine/?.lua"
require "bootstrap"
local task = dofile "/engine/task/bootstrap.lua"
task {
    bootstrap = { "s|listen", arg },
    logger = { "s|log.server" },
    exclusive = { "timer", "s|network", "subprocess" },
    debuglog = "server_log.txt",
}
