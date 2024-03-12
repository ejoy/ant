package.path = "/engine/?.lua"
require "bootstrap"

dofile "/engine/ltask.lua" {
    bootstrap = {
        ["logger"] = {},
        ["p|main"] = {
            args = arg,
            unique = false,
        }
    },
    exclusive = { "timer" },
}
