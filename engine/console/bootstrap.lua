local lfs = require "bee.filesystem"
local vfs = require "vfs"

local entry = lfs.absolute(arg[0])

vfs.initfunc("/engine/firmware/init_thread.lua", {
    editor = __ANT_EDITOR__,
}, true)

local boot = dofile "/engine/firmware/ltask.lua"
boot:start {
    core = {
        worker = 8,
    },
    root = {
        bootstrap = {
            {
                name = "io",
                unique = true,
                initfunc = [[return loadfile "/engine/console/io.lua"]],
                args = { entry:parent_path():string(), __ANT_EDITOR__ },
                worker_id = 3,
            },
            {
                name = "ant.ltask|timer",
                unique = true,
            },
            {
                name = "ant.ltask|logger",
                unique = true,
            },
            {
                name = "/"..entry:filename():string(),
                args = { arg },
            },
        },
    },
    mainthread = 0,
}
boot:wait()
