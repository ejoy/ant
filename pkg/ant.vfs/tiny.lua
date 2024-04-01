local lfs = require "bee.filesystem"
local fastio = require "fastio"
local mount = require "mount"
local new_vfsrepo = require "vfsrepo".new

local function new_tiny(rootpath)
    rootpath = lfs.path(rootpath)
    local cachepath = lfs.path(rootpath)
    assert(lfs.is_directory(rootpath))
    if not lfs.is_directory(cachepath) then
        assert(lfs.create_directories(cachepath))
    end
    local repo = { _root = rootpath }
    mount.read(repo)
    local vfsrepo = new_vfsrepo()
    local config = {
        hash = false,
        filter = {
            resource = { "material" , "glb" , "gltf" , "texture" },
            block = { "/res" },
            ignore = {},
            whitelist = nil,
        },
    }
    for i = 1, #repo._mountlpath do
        config[#config+1] = {
            mount = repo._mountvpath[i]:sub(1,-2),
            path = repo._mountlpath[i]:string(),
        }
    end
    vfsrepo:init(config)
    return vfsrepo
end

return function (repopath)
    local repo = new_tiny(repopath)
    local vfs = {}
    function vfs.read(pathname)
        local file = repo:file(pathname)
        if not file then
            return
        end
        if not file.path then
            return
        end
        local data = fastio.readall_v(file.path, pathname)
        return data, file.path
    end
    function vfs.realpath(pathname)
        local file = repo:file(pathname)
        if not file then
            return
        end
        if file.path then
            return file.path
        end
    end
    function vfs.list(pathname)
        local file = repo:file(pathname)
        if not file then
            return
        end
        if file.dir then
            local dir = {}
            for _, c in ipairs(file.dir) do
                if c.dir then
                    dir[c.name] = "d"
                elseif c.path then
                    dir[c.name] = "f"
                end
            end
            return dir
        end
    end
    function vfs.type(pathname)
        local file = repo:file(pathname)
        if file then
            if file.dir then
                return "d"
            elseif file.path then
                return "f"
            end
        end
    end
    function vfs.directory(what)
        if what == "repo" then
            return repopath
        elseif what == "internal" then
            return repopath ..".app/internal/"
        elseif what == "external" then
            return repopath ..".app/external/"
        end
    end
    return vfs
end
