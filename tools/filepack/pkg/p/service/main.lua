local ltask = require "ltask"
local fs = require "bee.filesystem"
local vfs = require "vfs"
local datalist = require "datalist"
local fastio = require "fastio"
local zip = require "zip"
local new_repo = import_package "ant.vfs"

local function hashpath(hash)
	return hash:sub(1,2) .. "/" .. hash
end

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
    repo = new_repo(repopath)
    setting = datalist.parse(fastio.readall(vfs.realpath "/compile.settings"))
end

do print "step2. pack root"
    local root = repo:root()
    zipfile:add("root", root)
end

do print "step3. pack resource"
    local CompileId = ltask.call(ServiceCompile, "SETTING", setting)
    local resource = {}
    local function compile_resource(i, path)
        local lpath = ltask.call(ServiceCompile, "COMPILE",  CompileId, path)
        local hash = repo:build_resource(lpath)
        resource[i] = ("%s %s\n"):format(hash, path)
    end

    local paths = repo:export_resources()
    local tasks = {}
    for i, path in ipairs(paths) do
        tasks[i] = {compile_resource, i, path}
    end
    for _ in ltask.parallel(tasks) do
    end
    zipfile:add(hashpath(repo:root())..".resource", table.concat(resource))
end

do print "step4. pack file and dir"
    for hash, v in pairs(repo._filehash) do
        if v.dir then
            zipfile:add(hashpath(hash), v.dir)
        else
            zipfile:addfile(hashpath(hash), v.path)
        end
    end
end

do print "step5. finish"
    zipfile:close()
    ltask.call(ServiceCompile, "QUIT")
end
