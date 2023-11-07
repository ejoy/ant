local ltask = require "ltask"
local fs = require "bee.filesystem"
local vfs = require "vfs"
local datalist = require "datalist"
local fastio = require "fastio"
local zip = require "zip"
local vfsrepo = import_package "ant.vfs"

local arg = ...
local zipfile
local repo
local ServiceCompile
local setting

do print "step1. init"
    local repopath = fs.absolute(arg[1]):lexically_normal()
    local zippath = vfs.repopath() .. ".repo.zip"
    fs.remove_all(zippath)
    zipfile = assert(zip.open(zippath, "w"))
    ServiceCompile = ltask.spawn("ant.compile_resource|compile", repopath:string())
    repo = vfsrepo.new_std(repopath, "/vfs")
    setting = datalist.parse(fastio.readall(vfs.realpath "/compile.settings"))
end

do print "step2. pack root"
    zipfile:add("root", repo:root())
end

do print "step3. pack resource"
    local CompileId = ltask.call(ServiceCompile, "SETTING", setting)
    local resource = {}
    local function compile_resource(i, name, path)
        local lpath = ltask.call(ServiceCompile, "COMPILE",  CompileId, path)
        local hash = repo:build_resource(lpath):root()
        resource[i] = ("%s %s\n"):format(hash, name)
    end

    local names, paths = repo:export_resources()
    local tasks = {}
    for i = 1, #names do
        tasks[i] = {compile_resource, i, names[i], paths[i]}
    end
    for _ in ltask.parallel(tasks) do
    end
    zipfile:add(repo:root()..".resource", table.concat(resource))
end

do print "step4. pack file and dir"
    for hash, v in pairs(repo._filehash) do
        if v.dir then
            zipfile:add(hash, v.dir)
        else
            zipfile:addfile(hash, v.path)
        end
    end
end

do print "step5. finish"
    zipfile:close()
    ltask.call(ServiceCompile, "QUIT")
end
