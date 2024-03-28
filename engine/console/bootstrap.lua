local lfs = require "bee.filesystem"

local entry = lfs.absolute(arg[0])

if entry:parent_path():filename():string() == "editor" then
    __ANT_EDITOR__ = arg[1]
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
            },
            {
                name = "ant.engine|timer",
                unique = true,
            },
            {
                name = "ant.engine|logger",
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
