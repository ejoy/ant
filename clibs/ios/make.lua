local lm = require "luamake"

if lm.os ~= "ios" then
    return
end

dofile "../common.lua"

lm:lua_source "ios" {
    sources = {
        "ios.mm",
    }
}
