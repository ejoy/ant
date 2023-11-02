local lfs = require "bee.filesystem"
local platform = require "bee.platform"

local function find_bindir()
    local antdir = os.getenv "antdir"
    if antdir then
        return lfs.path(antdir) / "bin/msvc/debug"
    end

    return lfs.exe_path():parent_path()
end

local BINDIR<const> = find_bindir()--lfs.exe_path():parent_path()
local TOOLSUFFIX<const> = platform.os == "macos" and "" or ".exe"

return function (toolname)
    local exepath = BINDIR / (toolname .. TOOLSUFFIX)
    if lfs.exists(exepath) then
        return exepath
    end
    error(table.concat({
        "Can't found tools in : ",
        "\t" .. tostring(exepath)
    }, "\n"))
end
