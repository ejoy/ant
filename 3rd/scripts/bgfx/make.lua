local lm = require "luamake"

require "common"
require "core.bx"
require "core.bimg"
require "core.bgfx"

if lm.os == "ios" then
    return
end

require "tools.shaderc"
require "tools.texturec"
