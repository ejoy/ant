package.path = "/engine/?.lua"
require "bootstrap"

dofile "/engine/ltask.lua" {
    bootstrap = {
        ["ant.ltask|logger"] = {},
        ["p|main"] = {
            args = arg,
            unique = false,
        }
    }
}
