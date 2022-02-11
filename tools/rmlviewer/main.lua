package.path = "engine/?.lua"
require "bootstrap"

local fs = require "bee.filesystem"
local inputfile = fs.path(assert(arg[1], "Need rml file"))
local vfs = require "vfs"
vfs.mount("/resource", inputfile:parent_path():string())

import_package "ant.window".start {
    args = {inputfile:filename():string()},
    import = {
        "@ant.tools.rmlviewer",
    },
    pipeline = {
        "init",
        "update",
        "exit",
    },
    system = {
        "ant.tools.rmlviewer|init_system",
    },
    policy = {
        "ant.general|name",
        "ant.scene|scene_object",
        "ant.render|render",
        "ant.render|render_queue",
    }
}
