package.path = "/engine/?.lua"
require "bootstrap"

dofile "/engine/ltask.lua" {
    bootstrap = {
        ["logger"] = {},
        ["test|main"] = {
            unique = false,
        }
    },
    exclusive =  { "timer" },
}
