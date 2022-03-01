local lm = require "luamake"

if lm.os ~= "ios" then
    lm:phony "source_gesture" {
    }
    return
end

dofile "../common.lua"

lm:source_set "source_gesture" {
    includes = {
        LuaInclude,
        "../window",
        Ant3rd.."bee.lua/3rd/lua-seri",
    },
    sources = {
        "gesture.mm",
    }
}
