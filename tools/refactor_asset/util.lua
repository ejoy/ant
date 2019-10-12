local util = {}; util.__index = util

local fs        = require "filesystem.local"
local stringify = require "utility.stringify"

util.package_path_mapper = {
    ["ant.resources.binary"]    = "packages/resources.binary",
    ["ant.resources"]           = "packages/resources",
    ["ant.modelviewer"]         = "tools/modelviewer",
    ["unity_viking"]            = "test/samples/unity_viking",
    ["bloom"]                   = "test/samples/bloom",
}

function util.to_sub_paths(path, paths)
    local fn = path:filename()
    if fn == nil or fn == fs.path "" then
        return
    end

    table.insert(paths, 1, fn)
    util.to_sub_paths(path:parent_path(), paths)
end

function util.extract_pkg_name(localpath, relative_paths)
    local paths ={}
    util.to_sub_paths(localpath, paths)
    local fullpath = fs.path ""
    for i=1, #paths do
        fullpath = fullpath / paths[i]
        local packagefile = fullpath / "package.lua"
        if fs.exists(packagefile) then
            local c = fs_util.raw_table(packagefile, true)
            if relative_paths then
                table.move(paths, i+1, #paths, 1, relative_paths)
            end
            return c.name
        end
    end
end

function util.same_parent_path(lhs, rhs)
    local lhs_paths, rhs_paths = {}, {}
    util.to_sub_paths(lhs, lhs_paths)
    util.to_sub_paths(rhs, rhs_paths)

    local samepath = fs.path ""
    for i=1, #lhs_paths do
        local lp = lhs_paths[i]
        local rp = rhs_paths[i]

        if lp ~= rp then
            break
        end

        samepath = samepath / lp
    end

    return samepath
end

function util.extract_child_path(parentpath, fullpath)
    local sameparent = util.same_parent_path(parentpath, fullpath)
    if sameparent == fs.path "" then
        return
    end

    return fs.path(fullpath:string():sub(#sameparent:string()+2))
end

function util.save_raw_table(filepath, content, mode)
	local str = stringify(content, true, true)
	local f = fs.open(filepath, mode or "w")
	f:write(str)
	f:close()
end

function util.to_pkg_path(localpath)
    local relative_paths = {}
    local pkgname = util.extract_pkg_name(localpath, relative_paths)
    if pkgname then
        local fullpath = fs.path "/pkg" / pkgname
        for _, p in ipairs(relative_paths) do
            fullpath = fullpath / p
        end
        return fullpath
    end
end

function util.to_local_path(pkgpath)
    local pkgname, relatepath = pkgpath:string():match "/pkg/([%w._]+)/(.+)$"
    local pkgrootpath = util.package_path_mapper[pkgname]
    return fs.path(pkgrootpath) / relatepath
end


return util