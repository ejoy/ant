local lfs = require "bee.filesystem"
local vfs = require "vfs"

return function (repopath, access)
    local repo
    function vfs.realpath(path)
        local rp = access.realpath(repo, path)
        if rp and lfs.exists(rp) then
            return rp:string()
        end
    end
    local ListValue <const> = {
        dir = true,
        file = false,
    }
    local function is_resource(path)
        path = path:string()
        local ext = path:match "[^/]%.([%w*?_%-]*)$"
        if ext ~= "material" and ext ~= "glb"  and ext ~= "texture" and ext ~= "png" then
            return false
        end
        if path:sub(1,8) == "/.build/" then
            return false
        end
        return true
    end
    function vfs.list(path)
        local item = {}
        for _, filename in ipairs(access.list_files(repo, path)) do
            item[filename] = ListValue[vfs.type(path .. filename)]
        end
        return item
    end
    function vfs.type(path)
        local rp = access.realpath(repo, path)
        if rp then
            if lfs.is_directory(rp) then
                return "dir"
            elseif is_resource(rp) then
                return "dir"
            elseif lfs.is_regular_file(rp) then
                return "file"
            end
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
