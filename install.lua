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

local fs = require "bee.filesystem"
local bytecode = dofile "tools/install/bytecode.lua"
local argument = dofile "packages/argument/main.lua"

local function copy_directory(from, to, filter)
    fs.create_directories(to)
    for fromfile in fs.pairs(from) do
        if (not filter) or filter(fromfile) then
            if fs.is_directory(fromfile) then
                copy_directory(fromfile, to / fromfile:filename(), filter)
            else
                if argument["bytecode"] and fromfile:equal_extension ".lua" then
                    bytecode(fromfile, to / fromfile:filename())
                else
                    fs.copy_file(fromfile, to / fromfile:filename(), fs.copy_options.overwrite_existing)
                end
            end
        end
    end
end

local input = fs.path "./"
local output = fs.path "../ant_release"
local BIN = fs.exe_path():parent_path()
local PLAT = BIN:parent_path():filename():string()

print "remove ant_release/* ..."
if fs.exists(output) then
    fs.remove_all(output / "bin")
    fs.remove_all(output / "engine")
    fs.remove_all(output / "packages")
    fs.remove_all(output / "tools")
else
    fs.create_directories(output)
end

print "copy data to ant_release/* ..."

copy_directory(BIN, output / "bin", function (path)
   return path:equal_extension '.dll' or path:equal_extension'.exe' or path:equal_extension'.lua'
end)
copy_directory(input / "engine", output / "engine", function (path)
    return path:filename():string() ~= ".gitignore"
end)
copy_directory(input / "packages", output / "packages", function (path)
    return path:filename():string() ~= ".gitignore"
end)
copy_directory(input / "docs", output / "doc")
copy_directory(input / "tools" / "prefab_editor", output / "tools" / "prefab_editor", function (path)
    return path ~= input / "tools" / "prefab_editor" / ".build"
end)
copy_directory(input / "tools" / "fileserver", output / "tools" / "fileserver")
fs.copy_file(input / "run_editor.bat", output / "run_editor.bat", fs.copy_options.overwrite_existing)

if PLAT == "msvc" then
    print "copy msvc depend dll"
    local msvc = dofile "tools/install/msvc_helper.lua"
    msvc.copy_vcrt("x64", output / "bin")
end

local function check_need_submit(...)
    for i=1, select('#', ...) do
        local a = select(1, ...)
        if a:match "submit" then
            return true
        end
    end
end

if check_need_submit(...) then
    print "submit ant_release ..."

    local subprocess = require "bee.subprocess"

    local cwd<const> = "../ant_release"
    local function spawn(cmd)
        print("spawn process:", cmd .. table.concat(cmd, " "))
        cmd.stdout = true
        cmd.stderr = true
        local p = subprocess.spawn(cmd)

        if p.stdout then
            print("stdout:", p.stdout:read "a")
        end

        if p.stderr then
            print("stderr:", p.stderr:read "a")
        end

        local errcode = p:wait()
        if errcode ~= 0 then
            print("error:", errcode)
        end
    end

    spawn{"git", "add", "."}
    local function find_commit_msg_in_arg(...)
        for i=1, select('#', ...) do
            local a = select(1, ...)
            local msg = a:match"commitmsg=(.+)"
            if msg then
                return msg
            end
        end
    end
    local commitmsg = find_commit_msg_in_arg(...) or "new"
    spawn{"git", "commit", "-m", commitmsg, "."}
    spawn{"git", "push"}
end