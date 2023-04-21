local util = {}
local fs = require "bee.filesystem"
local platform = require "bee.platform"

local function find_bindir()
    local antdir = os.getenv "antdir"
    if antdir then
        return fs.path(antdir) / "bin/msvc/debug"
    end

    return fs.exe_path():parent_path()
end
local BINDIR<const> = find_bindir()--fs.exe_path():parent_path()
local TOOLSUFFIX<const> = platform.os == "macos" and "" or ".exe"

function util.bin_dir()
    return BINDIR
end

function util.tool_exe_path(toolname)
    local exepath = BINDIR / (toolname .. TOOLSUFFIX)
    if fs.exists(exepath) then
        return exepath
    end
    error(table.concat({
        "Can't found tools in : ",
        "\t" .. tostring(exepath)
    }, "\n"))
end

return util
