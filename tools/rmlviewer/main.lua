package.path = "engine/?.lua"
require "bootstrap"

local arguments

if __ANT_RUNTIME__ then
    arguments = {"/pkg/vaststars.resources/ui/", "assemble.rml"}
else
    local fs = require "bee.filesystem"
    local inputfile = fs.path(assert(arg[1], "Need rml file"))
    arguments = {inputfile:string()}
end

import_package "ant.window".start {
    args = arguments,
    feature = {
        "ant.tools.rmlviewer",
        "ant.animation",
        "ant.rmlui",
        "ant.render",
    }
}
