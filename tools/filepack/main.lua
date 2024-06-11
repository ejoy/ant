local ltask = require "ltask"
local fs = require "bee.filesystem"
local sys = require "bee.sys"
local platform = require "bee.platform"
local zip = require "zip"
local vfsrepo = import_package "ant.vfs"
local cr = import_package "ant.compile_resource"

local function command(args)
	local result = {}
	local n = 1
	for _, arg in ipairs(args) do
		if arg:sub(1,1) == "-" then
			result[arg:sub(2)] = true
		else
			result[n] = arg; n = n + 1
		end
	end
	return result
end

local arg = command(...)

local path = arg[1]
local config_os = arg[2]
local VERBOSE = arg.v and print or function() end

config_os = config_os or platform.os

local repopath = fs.absolute(path):lexically_normal()
local resource_cache = {}

local platform_relates <const> = {
    windows = "direct3d11",
    macos = "metal",
    ios = "metal",
    android = "vulken",
}

local config_resource = {
    ("%s-%s"):format(config_os, platform_relates[config_os]),
}

do print "step1. check resource cache."
    for _, setting in ipairs(config_resource) do
        if fs.exists(repopath / "res" / setting) then
            for path, status in fs.pairs(repopath / "res" / setting) do
                if status:is_directory() then
                    for res in fs.pairs(path) do
                        resource_cache[res:string()] = true
                    end
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
    local function compile_resource(i, cfg, name, path)
        local lpath = cr.compile_file(cfg, name, path)
        resource_cache[lpath] = nil
    end
    for _, setting in ipairs(config_resource) do
        local cfg = cr.init_setting(tiny_vfs, setting)
        for i = 1, #names do
            tasks[#tasks+1] = { compile_resource, i, cfg, names[i], paths[i] }
        end
    end
    for _, resp in ltask.parallel(tasks) do
        if resp.error then
            log.error(resp.error)
            return
        end
    end
end

do print "step3. clean resource."
    for path in pairs(resource_cache) do
        fs.remove_all(path)
    end
end

local writer = {}

function writer.zip(bundlepath)
	VERBOSE ("Bundlepath:", bundlepath)
    local zippath = bundlepath / "00.zip"
    local hashpath = bundlepath / "00.hash"
    local m = {}
    function m.root(content)
        local f <close> = assert(io.open(hashpath:string(), "wb"))
        f:write(content)
    end
    if fs.exists(zippath) then
        local oldzippath = bundlepath / "00.old.zip"
        fs.rename(zippath, oldzippath)
        local oldzip = zip.open(oldzippath:string(), "r")
        if oldzip then
            local newzip = assert(zip.open(zippath:string(), "w"))
            function m.writefile(path, content)
                if oldzip:exist(path) then
                    newzip:copyfrom(path, oldzip)
                else
                    newzip:add(path, content)
                end
            end
            function m.copyfile(path, localpath)
                if oldzip:exist(path) then
                    newzip:copyfrom(path, oldzip)
                else
                    newzip:addfile(path, localpath)
                end
            end
            function m.close()
                oldzip:close()
                newzip:close()
                fs.remove(oldzippath)
            end
            return m
        end
    end
    fs.create_directories(bundlepath)
    local zipfile = assert(zip.open(zippath:string(), "w"))
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

function writer.dir(bundlepath)
    fs.create_directories(bundlepath)
    local cache = {}
    for file, status in fs.pairs(bundlepath) do
        if status:is_directory() then
            fs.remove_all(file)
        else
            cache[file:filename():string()] = true
        end
    end
    local m = {}
    function m.root(content)
        cache["root"] = nil
        local pathobj = bundlepath / "root"
        local f <close> = assert(io.open(pathobj:string(), "wb"))
        f:write(content)
    end
    function m.writefile(path, content)
        cache[path] = nil
        local pathobj = bundlepath / path
        if fs.exists(pathobj) then
            return
        end
        local f <close> = assert(io.open(pathobj:string(), "wb"))
        f:write(content)
    end
    function m.copyfile(path, localpath)
        cache[path] = nil
        fs.copy_file(localpath, bundlepath / path, fs.copy_options.skip_existing)
    end
    function m.close()
        for file in pairs(cache) do
            fs.remove(bundlepath / file)
        end
    end
    return m
end

do print "step4. pack file and dir."
    local std_vfs <close> = vfsrepo.new_std {
        rootpath = repopath,
        resource_settings = config_resource,
    }
    local function bundle_path()
        if config_os == "ios" then
            return repopath / ".ios"
        elseif config_os == "android" then
            return repopath / ".android"
        else
            return sys.exe_path():parent_path() / "internal"
        end
    end
    local w = writer.zip(bundle_path())
    w.root(std_vfs:root())
    for hash, v in pairs(std_vfs._filehash) do
        if v.dir then
            w.writefile(hash, v.dir)
        else
			VERBOSE(v.path, hash)
            w.copyfile(hash, v.path)
        end
    end
    w.close()
end

print "step5. done."
