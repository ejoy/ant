local lfs = require "filesystem.cpp"
local access = dofile "engine/vfs/repoaccess.lua"
local vfs = require "vfs"

return function (repopath)
    local repo
    function vfs.realpath(path)
        local rp = access.realpath(repo, path)
        if lfs.exists(rp) then
            return rp:string()
        end
    end
    function vfs.list(path)
        path = path:match "^/?(.-)/?$" .. '/'
        local item = {}
        for filename in pairs(access.list_files(repo, path)) do
            local realpath = access.realpath(repo, path .. filename)
            if realpath then
                item[filename] = not not lfs.is_directory(realpath)
            end
        end
        return item
    end
    function vfs.type(path)
        local rp = access.realpath(repo, path)
        if lfs.is_directory(rp) then
            return "dir"
        elseif lfs.is_regular_file(rp) then
            return "file"
        end
    end
    function vfs.repopath()
        return repopath
    end
    function vfs.mount(name, path)
        access.addmount(repo, name, path)
    end
    local path = lfs.path(repopath)
    if not lfs.is_directory(path) then
       error "Not a dir"
    end
    repo = {
        _root = path,
    }
    access.readmount(repo)
end
