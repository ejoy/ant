local lfs       = require "filesystem.local"
local platform  = require "platform"
local OS        = platform.OS
local CWD       = lfs.current_path()
local subprocess=require "subprocess"

local toolsuffix = OS == "OSX" and "" or ".exe"

local util = {}; util.__index = util

function util.rawtable(filepath)
	local env = {}
	local r = assert(lfs.loadfile(filepath, "t", env))
	r()
	return env
end

function util.identify_info(identity)
    return identity:match("([^-]+)-(.+)$")
end

function util.to_execute_path(pathname)
    return CWD / (pathname .. toolsuffix)
end

local function tool_paths(toolbasename)
    local vspath = "projects/msvc/vs_bin"
    local hasmsvc = package.cpath and package.cpath:match(vspath)

    local toolnameDebug = toolbasename .. "debug"
    local toolnameRelease = toolbasename .. "release"

    if hasmsvc then
        return {
            vspath .. "/x64/Release/" .. toolnameRelease,
            vspath .. "/x64/Debug/" .. toolnameDebug,
            vspath .. "/x64/Release/" .. toolbasename,
            vspath .. "/x64/Debug/" .. toolbasename,
            "bin/" .. toolbasename,
        }
    end
    return {
        "clibs/" .. toolnameRelease,
        "clibs/" .. toolnameDebug,
        "bin/" .. toolnameRelease,
        "bin/"  .. toolnameDebug,
        "bin/" .. toolbasename,
    }
end

function util.valid_tool_exe_path(toolname)
    local toolpaths = tool_paths(toolname)

    for _, name in ipairs(toolpaths) do
        local exepath = util.to_execute_path(name)
        if lfs.exists(exepath) then
            return exepath
        end
    end

    error(string.format("not found any valid texturec path. update bin folder or compile from 3rd/bgfx [texturec] project"))
end

function util.to_cmdline(commands)
    local s = ""
    for _, v in ipairs(commands) do
        if type(v) == "table" then
            for _, vv in ipairs(v) do
                s = s .. vv .. " "
            end
        else
            s = s .. v .. " "
        end
    end

    return s
end

function util.spaw_process(commands, checkmsg)
    local prog = subprocess.spawn(commands)
	print(util.to_cmdline(commands))

	if prog then
		local stds = {
			{fd=prog.stdout, info="[stdout info]:"},
			{fd=prog.stderr, info="[stderr info]:"}
		}

		local success, msg = true, ""
		while #stds > 0 do
			for idx, std in ipairs(stds) do
				local fd = std.fd
				local num = subprocess.peek(fd)
				if num == nil then
					local s, m = checkmsg(std.info)
					success = success and s
					msg = msg .. "\n\n" .. m
					table.remove(stds, idx)
					break
				end

				if num ~= 0 then
					std.info = std.info .. fd:read(num)
				end
			end
		end

		return success, msg
    end
    
    return false, "Create process failed."
end

return util