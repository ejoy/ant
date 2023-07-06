local EnginePath, ProjectPath = ...

local lfs = require "bee.filesystem"
lfs.current_path(EnginePath)

local access = dofile((lfs.current_path() / "engine" / "vfs" / "repoaccess.lua"):string())

local path = lfs.path(ProjectPath)
if not lfs.is_directory(path) then
   error "Not a dir"
end
local repo = {
    _root = path,
}
access.readmount(repo)

local function listfile(dir, func)
    local list = access.list_files(repo, dir)
    for _, v in ipairs(list) do
        local vpath = dir.."/"..v
        local rpath = access.realpath(repo, vpath)
        func(rpath)
        if "dir" == access.type(repo, vpath) then
            listfile(vpath, func)
        end
    end
end

listfile("", function (path)
    print(path)
end)
