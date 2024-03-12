package.path = "/engine/?.lua"
require "bootstrap"

dofile "/engine/ltask.lua" {
    exclusive = { "timer", "s|network" },
    bootstrap = {
        ["s|log.server"] = {},
        ["s|listen"] = {
            args = arg,
            unique = false,
        }
    },
}
