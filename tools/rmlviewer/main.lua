package.path = "/engine/?.lua"
require "bootstrap"

local arguments

if __ANT_RUNTIME__ then
    arguments = {"/pkg/vaststars.resources/ui/", "assemble.html"}
else
    local fs = require "bee.filesystem"
    local inputfile = fs.path(assert(arg[1], "Need html file"))
    arguments = {inputfile:string()}
end

import_package "ant.window".start {
    args = arguments,
    feature = {
        "ant.tools.rmlviewer",
        "ant.rmlui",
    }
}
