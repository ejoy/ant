package.path = table.concat(
    {
        "engine/?.lua",
        "packages/?.lua",
    }, ";"
)

package.cpath = "projects/msvc/vs_bin/Debug/?.dll"

local fs_util = require "utility.fs_util"
local stringify = require "utility.stringify"

local fs = require "filesystem.local"

local materialfiles = fs_util.list_files(fs.path "", ".material", {})

local pkg_subpath = fs.path "packages" / "resources"

local function to_sub_paths(path, paths)
    local fn = path:filename()
    if fn == nil or fn == fs.path "" then
        return
    end

    table.insert(paths, 1, fn)
    to_sub_paths(path:parent_path(), paths)
end

local function same_parent_path(lhs, rhs)
    local lhs_paths, rhs_paths = {}, {}
    to_sub_paths(lhs, lhs_paths)
    to_sub_paths(rhs, rhs_paths)

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

local function extract_child_path(parentpath, fullpath)
    local sameparent = same_parent_path(parentpath, fullpath)
    if sameparent == fs.path "" then
        return
    end

    return fs.path(fullpath:string():sub(#sameparent:string()+2))
end

local function save_depiction_file(filepath, content)
    local str = stringify(content, true, true)
    local f = fs.open(filepath, "w")
    f:write(str)
    f:close()
end

local function pkg_name(localpath, relative_paths)
    local paths ={}
    to_sub_paths(localpath, paths)
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

local function to_pkg_path(localpath)
    local relative_paths = {}
    local pkgname = pkg_name(localpath, relative_paths)
    if pkgname then
        local fullpath = fs.path "/pkg" / pkgname
        for _, p in ipairs(relative_paths) do
            fullpath = fullpath / p
        end
        return fullpath
    end
end

local function get_fx_subpath(originpath)
    local pkgname = pkg_name(originpath)
    if pkgname == "ant.resources" then
        return fs.path "packages" / "resources" / "depiction" / "materials" / "fx"
    end

    if pkgname == "unity_viking" then
        return fs.path "test" / "samples" / "unity_viking" / "Assets" / "materials" / "fx"
    end

    if pkgname == "bloom" then
        return fs.path "test" / "samples" / "bloom" / "assets" / "fx"
    end

    if pkgname == "ant.modelviewer" then
        return fs.path "tools" / "modelviewer" / "fx"
    end
end

for _, mf in ipairs(materialfiles) do
    local materialcontent = fs_util.raw_table(mf)
    local fxcontent = {
        shader      = materialcontent.shader,
        surface_type= materialcontent.surface_type,
    } 

    local fx_subpath = get_fx_subpath(mf)
    local subchildpath = extract_child_path(fx_subpath, mf)
    subchildpath:replace_extension ".fx"
    local fxfile = fx_subpath / subchildpath
    fs.create_directories(fxfile:parent_path())

    save_depiction_file(fxfile, fxcontent)

    materialcontent.shader          = nil
    materialcontent.surface_type    = nil
    materialcontent.fx              = to_pkg_path(fxfile):string()
    save_depiction_file(mf, materialcontent)
end

