local lm = require "luamake"

local rootdir = "../../../../"

lm:lua_src "textcell" {
    sources = {
        "cell.c",
    },
}