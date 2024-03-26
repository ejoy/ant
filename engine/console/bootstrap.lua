local lfs = require "bee.filesystem"
local vfs = require "vfs"

local entry = lfs.absolute(arg[0])

if entry:parent_path():filename():string() == "editor" then
    __ANT_EDITOR__ = arg[1]
    vfs.initfunc("/engine/console/init_thread.lua", {
        __ANT_EDITOR__ = __ANT_EDITOR__,
    }, true)
end

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
