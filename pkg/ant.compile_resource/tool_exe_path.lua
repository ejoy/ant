local lfs = require "bee.filesystem"
local platform = require "bee.platform"

local BASETOOLS<const> = {
    "shaderc", "texturec", "gltf2ozz"
}

local TOOLSUFFIX<const> = platform.os == "windows" and ".exe" or ""

local function check_tool_path_valid(path)
    if not lfs.exists(path) then
        return false
    end
    for _, n in ipairs(BASETOOLS) do
        if not lfs.exists(path / (n .. TOOLSUFFIX)) then
            return false
        end
    end

    return true
end

local function find_bindir()
    local antdir = os.getenv "antdir"
    local rootpath
    if antdir then
        rootpath = lfs.path(antdir) / "bin" / platform.CRT
    else
        rootpath = lfs.exe_path():parent_path():parent_path()
    end

    local releasepath = rootpath / "release"
    if check_tool_path_valid(releasepath) then
        return releasepath
    end

    local debugpath = rootpath / "debug"
    if check_tool_path_valid(debugpath) then
        log.info("Use the debug tools path, but release path can greatly improve resource compilation efficiency, make sure build the release tool path: luamake tools -mode release")
        return debugpath
    end

    error(("No valid tool paths, make sure [release/debug] sub path contain tools: shaderc, texturec, gltf2ozz"):format(rootpath))
end

local BINDIR<const>     = find_bindir()--lfs.exe_path():parent_path()
log.info(("Use tools path:"):format(BINDIR))

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
