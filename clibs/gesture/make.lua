local lm = require "luamake"

if lm.os ~= "ios" then
    return
end

dofile "../common.lua"

lm:lua_source "gesture" {
    includes = {
        "../window",
        Ant3rd.."bee.lua/3rd/lua-seri",
    },
    sources = {
        "gesture.mm",
    }
}
