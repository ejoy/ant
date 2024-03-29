do
    local function LoadFile(path, env)
        local fastio = require "fastio"
        local data = fastio.readall_v(path, path)
        local func, err = fastio.loadlua(data, path, env)
        if not func then
            error(err)
        end
        return func
    end
    local function LoadDbg(expr)
        local env = setmetatable({}, {__index = _G})
        function env.dofile(path)
            return LoadFile(path, env)()
        end
        assert(load(expr, "=(expr)", "t", env))()
    end
    local i = 1
    while true do
        if arg[i] == nil then
            break
        elseif arg[i] == '-e' then
            assert(arg[i + 1], "'-e' needs argument")
            LoadDbg(arg[i + 1])
            table.remove(arg, i)
            table.remove(arg, i)
            break
        end
        i = i + 1
    end
end

local fs = require "bee.filesystem"
local vfs = require "vfs"

local ENTRY = fs.absolute(arg[0])
local REPOPATH = ENTRY:parent_path():string():gsub("/?$", "/")

function vfs.repopath()
    return REPOPATH
end

if ENTRY:parent_path():filename():string() == "editor" then
    __ANT_EDITOR__ = arg[1]
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
