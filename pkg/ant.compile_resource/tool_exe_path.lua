local lfs = require "bee.filesystem"
local sys = require "bee.sys"
local platform = require "bee.platform"

local BASETOOLS<const> = {
	shaderc = 1,
	texturec = 1,
	gltf2ozz = 1,
}

local TOOLSUFFIX<const> = platform.os == "windows" and ".exe" or ""

local function checkversion(path)
	local version = path / "tools_version"
	local f <close> = io.open(version:string())
	if not f then
		return false
	end
	local env = {}
	local code = load(f:read "a", "version", "t", env)
	if not code then
		return false
	end
	if not pcall(code) then
		return false
	end
	for name, v in pairs(BASETOOLS) do
		local vf = tonumber(env[name])
		if not vf then
			return false
		end
		if vf < v then
			return false
		end
	end
	return true
end

local function check_tool_path_valid(path)
    if not lfs.exists(path) then
        return false
    end
    for name, version in pairs(BASETOOLS) do
        if not lfs.exists(path / (name .. TOOLSUFFIX)) then
            return false
        end
    end
    return true
end

local function find_bindir()
    local rootpath = sys.exe_path():parent_path():parent_path()

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
if not checkversion(BINDIR) then
	error "Tools are expired, run `luamake tools` first"
end

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
