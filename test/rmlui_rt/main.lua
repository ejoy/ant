package.path = "/engine/?.lua"
require "bootstrap"

local arguments

if __ANT_RUNTIME__ then
    arguments = {"/pkg/vaststars.resources/ui/", "assemble.html"}
else
    local fs = require "bee.filesystem"
    local inputfile = fs.path(assert(arg[1], "Need html file"))
    local vfs = require "vfs"
    vfs.mount("test/rmlui/")
    arguments = {inputfile:string()}
end

import_package "ant.window".start {
    args = arguments,
    feature = {
        "ant.test.rmlui_rt",
        "ant.rmlui",
        "ant.sky|sky",
    }
}
