local lm = require "luamake"

if lm.os == "windows" then
    lm:source_set "bgfx-support-utf8" {
        sources = "utf8/utf8.rc"
    }
end
