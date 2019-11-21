local lfs       = require "filesystem.local"
local platform  = require "platform"
local OS        = platform.OS
local CWD       = lfs.current_path()
local subprocess=require "subprocess"
local vspath    = "projects/msvc/vs_bin"

local function is_msvc()
    local function has_arg(name)
		for _, a in ipairs(arg) do
			if a == name then
				return true
			end
		end
    end
    
    return has_arg("--bin=msvc")
end

local function which_platfrom_type()
    if OS == "Windows" then
        return is_msvc() and "msvc" or "mingw"
    else
        return "osx"
    end
end
local plattype = which_platfrom_type()

local toolsuffix = OS == "OSX" and "" or ".exe"

local util = {}; util.__index = util

function util.rawtable(filepath)
	local env = {}
	local r = assert(lfs.loadfile(filepath, "t", env))
	r()
	return env
end

function util.identify_info(identity)
    return identity:match("%.(%w+)%[([%s%w]+)%]_(%w+)$")
end

function util.to_execute_path(pathname)
    return CWD / (pathname .. toolsuffix)
end

local function tool_paths(toolbasename)
    local toolnameDebug = toolbasename .. "Debug"
    local toolnameRelease = toolbasename .. "Release"
    local function to_binpath(name)
        return "bin/" .. plattype .. "/" .. name
    end

    if plattype == "msvc" then
        return {
            vspath .. "/Release/" .. toolnameRelease,
            vspath .. "/Debug/" .. toolnameDebug,
            vspath .. "/Release/" .. toolbasename,
            vspath .. "/Debug/" .. toolbasename,
            to_binpath(toolbasename),
        }
    end

    return {
        "clibs/" .. toolbasename,
        "clibs/" .. toolnameRelease,
        "clibs/" .. toolnameDebug,
        to_binpath(toolnameRelease),
        to_binpath(toolnameDebug),
        to_binpath(toolbasename),
    }
end

function util.valid_tool_exe_path(plat, toolname)
    local toolpaths = tool_paths(plat, toolname)

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

local function def_check_msg(msg)
    return true, msg
end

function util.spawn_process(commands, checkmsg)
    checkmsg = checkmsg or def_check_msg
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
        
        local errcode = prog:wait()
        if errcode == 0 then
            return success, msg
        end
		return false, msg .. string.format("\nsubprocess failed, error code:%x", errcode)
    end
    
    return false, "Create process failed."
end

function util.fetch_file_content(filepath)
	local f = lfs.open(filepath, "rb")
	local c = f:read "a"
	f:close()
	return c
end

function util.write_embed_file(filepath, luacontent, binarys)
    local f = lfs.open(filepath, "wb")
    f:write("res\0")

    f:write("lua\0", string.pack("<I4", #luacontent), luacontent)

    local binarybytes = 0
    for _, b in ipairs(binarys) do
        binarybytes = binarybytes + #b
    end
    f:write("bin\0", string.pack("<I4", binarybytes), table.unpack(binarys))
    f:close()
end

function util.embed_file(filepath, luacontent, binarys)
    local utility = import_package "ant.utility.local"
	local stringify = utility.stringify
    local s = stringify(luacontent, true, true)
    util.write_embed_file(filepath, s, binarys)
end

util.shadertypes = {
	NOOP       = "d3d9",
	DIRECT3D9  = "d3d9",
	DIRECT3D11 = "d3d11",
	DIRECT3D12 = "d3d11",
	GNM        = "pssl",
	METAL      = "metal",
	OPENGL     = "glsl",
	OPENGLES   = "essl",
	VULKAN     = "spirv",
}

return util