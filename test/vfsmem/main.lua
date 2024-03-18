package.path = "/engine/?.lua"
require "bootstrap"

dofile "/engine/ltask.lua" {
    bootstrap = {
        ["ant.ltask|logger"] = {},
        ["test|main"] = {
            unique = false,
        }
    }
}
