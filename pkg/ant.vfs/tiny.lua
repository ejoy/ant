local lfs = require "bee.filesystem"
local fastio = require "fastio"
local datalist = require "datalist"
local access = dofile "/engine/editor/vfs_access.lua"
local new_vfsrepo = require "vfsrepo".new

local function read_vfsignore(rootpath)
    if not lfs.exists(rootpath / ".vfsignore") then
        return {}
    end
    local r = datalist.parse(fastio.readall((rootpath / ".vfsignore"):string()))
    if r.block then
        table.insert(r.block, 1, "/res")
    else
        r.block = { "/res" }
    end
    return r
end

local resource <const> = { "material" , "glb" , "texture" }

local compile_whitelist <const> = {
    "settings",
    "cfg",
    -- ecs
    "prefab",
    "ecs",
    -- script
    "lua",
    -- ui
    "rcss",
    "rml",
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
    -- material
    "state",
    --compile
    "sc",
    "sh",
    "png",
    "hdr",
    "dds",
}

local function new_tiny(rootpath)
    rootpath = lfs.path(rootpath)
    local cachepath = lfs.path(rootpath) / ".fileserver"
    assert(lfs.is_directory(rootpath))
    if not lfs.is_directory(cachepath) then
        -- already has .repo
        assert(lfs.create_directories(cachepath))
    end
    local repo = { _root = rootpath }
    access.readmount(repo)
    local vfsrepo = new_vfsrepo()
    local vfsignore = read_vfsignore(rootpath)
    local config = {
        hash = false,
        filter = {
            resource = resource,
            whitelist = compile_whitelist,
            block = vfsignore.block,
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
