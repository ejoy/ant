local fs = require "bee.filesystem"

local ENTRY = fs.absolute(arg[0])
local REPOPATH = ENTRY:parent_path():string():gsub("/?$", "/")

if ENTRY:parent_path():filename():string() == "editor" then
    __ANT_EDITOR__ = arg[1]
    assert(fs.is_directory(__ANT_EDITOR__), "Editor open project path:" .. __ANT_EDITOR__ .. " is not a directory.")
end

local boot = dofile "/engine/firmware/ltask.lua"
boot:start {
    core = {
        worker = 8,
        debuglog = REPOPATH .. "debug.log",
        crashlog = REPOPATH .. "crash.log",
    },
    root = {
        bootstrap = {
            {
                name = "io",
                unique = true,
                initfunc = [[return loadfile "/engine/console/io.lua"]],
                args = { REPOPATH, __ANT_EDITOR__ },
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
                name = "/"..ENTRY:filename():string(),
                args = { arg },
            },
        },
    },
    mainthread = 0,
}
boot:wait()
