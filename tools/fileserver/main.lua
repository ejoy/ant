package.path = "/engine/?.lua"
require "bootstrap"

dofile "/engine/ltask.lua" {
    bootstrap = {
        ["s|network"] = {},
        ["s|listen"] = {
            args = arg,
            unique = false,
        }
    },
}
