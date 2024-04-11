local lm = require "luamake"

if lm.os == "ios" then
    return
end

lm:lua_source "filedialog" {
    windows = {
        includes = lm.AntDir .. "/3rd/bee.lua",
        sources =  "filedialog.cpp",
        links = {
            "ole32",
            "uuid",
        }
    },
    macos = {
        sources =  "filedialog.mm",
    }
}
