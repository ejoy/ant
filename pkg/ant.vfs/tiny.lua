local lfs = require "bee.filesystem"
local fastio = require "fastio"
local datalist = require "datalist"
local mount = dofile "/engine/mount.lua"
local new_vfsrepo = require "vfsrepo".new

local function read_vfsignore(rootpath)
    if not lfs.exists(rootpath / ".vfsignore") then
        return {}
    end
    return datalist.parse(fastio.readall_f((rootpath / ".vfsignore"):string()))
end

local block <const> = {
    "/res",
    "/pkg/ant.bake",
    "/pkg/ant.resources.binary/meshes",
    "/pkg/ant.resources.binary/test",
}

local resource <const> = { "material" , "glb" , "texture" }

local compile_whitelist <const> = {
    "ant",
    -- ecs
    "prefab",
    "ecs",
    -- script
    "lua",
    -- ui
	"html",
	"css",
    -- effect
    "efk",
    -- font
    "ttf",
    "otf", --TODO: remove it?
    "ttc", --TODO: remove it?
    -- sound
    "bank",
    -- animation
    "event",
    "anim",
    "bin",
    -- material
    "state",
    "setting",
    --compile
    "sc",
    "sh",
    "png",
    "hdr",
    "dds",
    "varyings",
    "names"
}

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
    local vfsignore = read_vfsignore(rootpath)
    local config = {
        hash = false,
        filter = {
            resource = resource,
            whitelist = compile_whitelist,
            block = block,
            ignore = vfsignore.ignore,
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
                    dir[c.name] = { type = "d" }
                elseif c.path then
                    dir[c.name] = { type = "f" }
                end
            end
            return dir
        end
    end
    function vfs.type(pathname)
        local file = repo:file(pathname)
        if file then
            if file.dir then
                return "dir"
            elseif file.path then
                return "file"
            end
        end
    end
    function vfs.repopath()
        return repopath
    end
    return vfs
end
