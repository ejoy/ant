local lfs = require "bee.filesystem"
local platform = require "bee.platform"

local function find_bindir()
    local antdir = os.getenv "antdir"
    if antdir then
        return lfs.path(antdir) / "bin/msvc/debug"
    end

    local exepath = lfs.exe_path():parent_path()

    local mode = exepath:stem():string()
    if "release" == mode then
        return exepath
    end

    local release_path = exepath:parent_path() / "release"
    if lfs.exists(release_path) then
        return release_path
    end

    log.info("release tools is not build, release tools are mush faster than debug tools, try to build release tools: luamake tools -mode release")
    return lfs.exists(release_path) and release_path or exepath
end

local BINDIR<const>     = find_bindir()--lfs.exe_path():parent_path()
log.info(("Use tools path:"):format(BINDIR))
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
