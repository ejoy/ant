local ltask = require "ltask"
local fs = require "bee.filesystem"
local vfs = require "vfs"
local fastio = require "fastio"
local datalist = require "datalist"
local zip = require "zip"
local vfsrepo = import_package "ant.vfs"
local cr = import_package "ant.compile_resource"

local arg = ...
local repopath = fs.absolute(arg[1]):lexically_normal()
local config = datalist.parse(fastio.readall(vfs.realpath "/resource.settings"))
local resource_cache = {}

do print "step1. check resource cache."
    for _, setting in ipairs(config.resource) do
        for path, status in fs.pairs(repopath / "res" / setting) do
            if status:is_directory() then
                for res in fs.pairs(path) do
                    resource_cache[res:string()] = true
                end
            end
        end
    end
end

do print "step2. compile resource."
    local std_vfs <close> = vfsrepo.new_std {
        rootpath = repopath,
        nohash = true,
    }
    local tiny_vfs = vfsrepo.new_tiny(repopath)
    local names, paths = std_vfs:export_resources()
    local tasks = {}
    local function compile_resource(cfg, name, path)
        local lpath = cr.compile_file(cfg, name, path)
        resource_cache[lpath] = nil
    end
    for _, setting in ipairs(config.resource) do
        local cfg = cr.init_setting(tiny_vfs, setting)
        for i = 1, #names do
            tasks[#tasks+1] = { compile_resource, cfg, names[i], paths[i] }
        end
    end
    for _ in ltask.parallel(tasks) do
    end
end

do print "step3. clean resource."
    for path in pairs(resource_cache) do
        fs.remove_all(path)
    end
end

local writer = {}

function writer.zip()
    local zippath = vfs.repopath() .. ".repo.zip"
    fs.remove_all(zippath)
    local zipfile = assert(zip.open(zippath, "w"))
    local m = {}
    function m.writefile(path, content)
        zipfile:add(path, content)
    end
    function m.copyfile(path, localpath)
        zipfile:addfile(path, localpath)
    end
    function m.close()
        zipfile:close()
    end
    return m
end

function writer.loc()
    local function app_path(name)
        local platform = require "bee.platform"
        if platform.os == 'windows' then
            return fs.path(os.getenv "LOCALAPPDATA") / name
        elseif platform.os == 'linux' then
            return fs.path(os.getenv "XDG_DATA_HOME" or (os.getenv "HOME" .. "/.local/share")) / name
        elseif platform.os == 'macos' then
            return fs.path(os.getenv "HOME" .. "/Library/Caches") / name
        else
            error "unknown os"
        end
    end
    local rootpath = app_path "ant" / ".repo"
    fs.remove_all(rootpath)
    fs.create_directories(rootpath)
    local m = {}
    function m.writefile(path, content)
        local f <close> = assert(io.open((rootpath / path):string(), "wb"))
        f:write(content)
    end
    function m.copyfile(path, localpath)
        fs.copy_file(localpath, rootpath / path, fs.copy_options.overwrite_existing)
    end
    function m.close()
    end
    return m
end

do print "step4. pack file and dir."
    local std_vfs <close> = vfsrepo.new_std {
        rootpath = repopath,
        resource_settings = config.resource,
    }
    local target = config.target or "loc"
    local w = writer[target]()
    w.writefile("root", std_vfs:root())
    for hash, v in pairs(std_vfs._filehash) do
        if v.dir then
            w.writefile(hash, v.dir)
        else
            w.copyfile(hash, v.path)
        end
    end
    w.close()
end

print "step5. done."
