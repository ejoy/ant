package.path = "/engine/?.lua"
require "bootstrap"

dofile "/engine/task/bootstrap.lua" {
    bootstrap = { "s|listen", arg },
    exclusive = { "timer", "s|network", "subprocess" },
    logger = { "s|log.server" },
}
