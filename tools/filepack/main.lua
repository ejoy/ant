package.path = "/engine/?.lua"
require "bootstrap"

dofile "/engine/ltask.lua" {
    bootstrap = {
        ["p|main"] = {
            args = arg,
            unique = false,
        }
    }
}
