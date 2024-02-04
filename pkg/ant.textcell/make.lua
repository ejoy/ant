local lm = require "luamake"

local rootdir = "../../../../"

lm:lua_source "textcell" {
    sources = {
        "cell.c",
    },
}