local fs_util = require "fs_util"

local fs = require "filesystem.local"
local platform = require "platform"

local u = {}; u.__index = u

function u.datalist(filepath)
	return fs_util.datalist(fs, filepath)
end

function u.raw_table(filepath, fetchresult)
	return fs_util.raw_table(fs, filepath, fetchresult)
end

function u.read_file(filepath)
    return fs_util.read_file(fs, filepath)
end

function u.list_files(subpath, filter, excludes, add_path)
	local prefilter = {}
	if type(filter) == "string" then
		for f in filter:gmatch("([.%w]+)") do
			local ext = f:upper()
			prefilter[ext] = true
		end
    end
    
    add_path = add_path or function (p) return p end

	local function list_fiels_1(subpath, filter, excludes, files)
		for p in subpath:list_directory() do
			local name = p:filename():string()
			if not excludes[name] then
				if fs.is_directory(p) then
					list_fiels_1(p, filter, excludes, files)
				else
					if type(filter) == "function" then
						if filter(p) then
							files[#files+1] = add_path(p)
						end
					else
						local fileext = p:extension():string():upper()
						if filter[fileext] then
							files[#files+1] = add_path(p)
						end
					end
				end
			end
		end
	end
    local files = {}
    list_fiels_1(subpath, prefilter, excludes, files)
    return files
end

function u.write_file(filepath, c)
    local f = fs.open(filepath, "wb")
    f:write(c)
    f:close()
end

local OS = platform.OS
local vspath    = "projects/msvc/vs_bin"

local function is_msvc()
    -- TODO
    return package.cpath:match 'projects[\\/]msvc[\\/]vs_bin' ~= nil
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

local function to_execute_path(pathname)
    local CWD       = fs.current_path()
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

function u.valid_tool_exe_path(toolname)
    local toolpaths = tool_paths(toolname)

    for _, name in ipairs(toolpaths) do
        local exepath = to_execute_path(name)
        if fs.exists(exepath) then
            return exepath
        end
    end

	local dirs = { "Can't found tools in : " }
    for _, name in ipairs(toolpaths) do
        local exepath = to_execute_path(name)
		table.insert(dirs, "\t" .. tostring(exepath))
    end

    error(table.concat(dirs, "\n"))
end

function u.print_glb_compile_result(glbfile)
	local cr = import_package "compile_resource"
	local outpath = cr.compile(glbfile)

    local skinbin_files = u.list_files(fs.path(outpath) / "meshes", ".skinbin", {})
    print("skinbin files")
    for _, f in ipairs(skinbin_files) do
        print("  " .. f:string())
    end

    local meshbin_files = u.list_files(fs.path(outpath) / "meshes", ".meshbin", {})
    print("meshbin files")
    for _, f in ipairs(skinbin_files) do
        print("  " .. f:string())
    end
end

return u