package.path = "engine/?.lua"
require "bootstrap"
local task = dofile "/engine/task/bootstrap.lua"
task {
    service_path = "/pkg/ant.tools.fileserver/service/?.lua",
    lua_path = "/pkg/ant.tools.fileserver/lualib/?.lua",
    bootstrap = { "listen", arg },
    logger = { "log.server" },
    exclusive = { "timer", "network" },
    debuglog = "log.txt",
}
