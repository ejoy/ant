local fs = require 'filesystem.cpp'

--直到mingw 8.2，仍然有许多不符合标准的行为，所以打几个补丁，以便让测试通过。
local fs_remove = fs.remove
function fs.remove(path)
    if not fs.exists(path) then
        return false
    end
    return fs_remove(path)
end
local fs_copy_file = fs.copy_file
function fs.copy_file(from, to, flag)
    if flag and fs.exists(to) then
        fs.remove(to)
    end
    return fs_copy_file(from, to, flag)
end
local path_mt = debug.getmetatable(fs.path())
local path_is_absolute = path_mt.is_absolute
function path_mt.is_absolute(path)
    if path:string():sub(1, 2):match '[/\\][/\\]' then
        return true
    end
    return path_is_absolute(path)
end
function path_mt.is_relative(path)
    return not path_mt.is_absolute(path)
end
local path_string = path_mt.string
function path_mt.string(path)
    return path_string(path):gsub('\\', '/')
end
function path_mt.parent_path(path)
    return fs.path(path:string():match("(.+)[/\\][%w_.-]*$") or "")
end

return fs
