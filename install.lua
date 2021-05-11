local path_sep = package.config:sub(3,3)
if package.cpath:match(path_sep) then
	local ext = package.cpath:match '[/\\]%?%.([a-z]+)'
	package.cpath = (function ()
		local i = 0
		while arg[i] ~= nil do
			i = i - 1
		end
		local dir = arg[i + 1]:match("(.+)[/\\][%w_.-]+$")
		return ("%s/?.%s"):format(dir, ext)
	end)()
end

local fs = require "filesystem.cpp"
local bytecode = dofile "tools/install/bytecode.lua"
local argument = dofile "packages/argument/main.lua"

local function copy_directory(from, to, filter)
    fs.create_directories(to)
    for fromfile in from:list_directory() do
        if (not filter) or filter(fromfile) then
            if fs.is_directory(fromfile) then
                copy_directory(fromfile, to / fromfile:filename(), filter)
            else
                if argument["bytecode"] and fromfile:equal_extension ".lua" then
                    bytecode(fromfile, to / fromfile:filename())
                else
                    fs.copy_file(fromfile, to / fromfile:filename(), true)
                end
            end
        end
    end
end

local input = fs.path "./"
local output = fs.path "../ant_release"
local BIN = fs.exe_path():parent_path()
local PLAT = BIN:parent_path():filename():string()

if fs.exists(output) then
    fs.remove_all(output / "bin")
    fs.remove_all(output / "engine")
    fs.remove_all(output / "packages")
    fs.remove_all(output / "tools")
else
    fs.create_directories(output)
end

copy_directory(BIN, output / "bin", function (path)
   return path:equal_extension '.dll' or path:equal_extension'.exe'
end)
copy_directory(input / "engine", output / "engine")
copy_directory(input / "packages", output / "packages")
copy_directory(input / "tools" / "prebuilt", output / "tools" / "prebuilt")
copy_directory(input / "tools" / "prefab_editor", output / "tools" / "prefab_editor", function (path)
    return path ~= input / "tools" / "prefab_editor" / ".build"
end)

fs.copy_file(input / "run_editor.bat", output / "run_editor.bat", true)

if PLAT == "msvc" then
    local msvc = require "tools.install.msvc_helper"
    msvc.copy_vcrt("x64", output / "bin")
end
