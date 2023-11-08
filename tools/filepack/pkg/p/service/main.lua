local ltask = require "ltask"
local fs = require "bee.filesystem"
local vfs = require "vfs"
local fastio = require "fastio"
local zip = require "zip"
local vfsrepo = import_package "ant.vfs"
local cr = import_package "ant.compile_resource"

local arg = ...
local repopath = fs.absolute(arg[1]):lexically_normal()
local resource_settings = {}
local resource_cache = {}

do print "step1. check resource cache"
    for line in fastio.readall_s(vfs.realpath "/resource.settings"):gmatch "(.-)\n+" do
        resource_settings[#resource_settings+1] = line:match "(%S+)"
    end
    for _, setting in ipairs(resource_settings) do
        for path, status in fs.pairs(repopath / "res" / setting) do
            if status:is_directory() then
                for res in fs.pairs(path) do
                    resource_cache[res:string()] = true
                end
            end
        end
    end
end

do print "step2. compile resource"
    local std_vfs <close> = vfsrepo.new_std {
        rootpath = repopath,
        nohash = true,
    }
    local tiny_vfs = vfsrepo.new_tiny(repopath)
    local names, paths = std_vfs:export_resources()
    local tasks = {}
    local function compile_resource(config, name, path)
        local lpath = cr.compile_file(config, name, path)
        resource_cache[lpath] = nil
    end
    for _, setting in ipairs(resource_settings) do
        local config = cr.init_setting(tiny_vfs, setting)
        for i = 1, #names do
            tasks[#tasks+1] = { compile_resource, config, names[i], paths[i] }
        end
    end
    for _ in ltask.parallel(tasks) do
    end
end

do print "step3. clean resource"
    for path in pairs(resource_cache) do
        fs.remove_all(path)
    end
end

do print "step4. pack file and dir"
    local zippath = vfs.repopath() .. ".repo.zip"
    fs.remove_all(zippath)
    local zipfile = assert(zip.open(zippath, "w"))
    local std_vfs <close> = vfsrepo.new_std {
        rootpath = repopath,
        resource_settings = resource_settings,
    }
    zipfile:add("root", std_vfs:root())
    for hash, v in pairs(std_vfs._filehash) do
        if v.dir then
            zipfile:add(hash, v.dir)
        else
            zipfile:addfile(hash, v.path)
        end
    end
    zipfile:close()
end

print "step3 done."
