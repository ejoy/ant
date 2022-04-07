local lm = require "luamake"

if lm.os == "ios" then
    return
end

lm:lua_source "filedialog" {
    windows = {
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
