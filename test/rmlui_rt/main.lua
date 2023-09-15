package.path = "engine/?.lua"
require "bootstrap"

local arguments

if __ANT_RUNTIME__ then
    arguments = {"/pkg/vaststars.resources/ui/", "assemble.rml"}
else
    local fs = require "bee.filesystem"
    local inputfile = fs.path(assert(arg[1], "Need rml file"))
    local vfs = require "vfs"
    vfs.mount("test/rmlui/")
    arguments = {inputfile:string()}
end

import_package "ant.window".start {
    args = arguments,
    import = {
        "@ant.test.rmlui_rt",
    },
    feature = {
        "ant.rmlui",
        "ant.sky|sky",
    },
    system = {
        "ant.test.rmlui_rt|init_system",
    },
    policy = {
        "ant.render|render",
        "ant.render|render_queue",
    }
}
