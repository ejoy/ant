package.path = table.concat(
    {
        "./?.lua",
        "engine/?.lua",
        "packages/?.lua",
    }, ";"
)

package.cpath = "projects/msvc/vs_bin/Debug/?.dll"

local fs_util = require "utility.fs_util"
local util = require "util"

local fs = require "filesystem.local"

local materialfiles = fs_util.list_files(fs.path "", ".material", {})

local function get_fx_subpath(originpath)
    local pkgname = util.extract_pkg_name(originpath)
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
    local subchildpath = util.extract_child_path(fx_subpath, mf)
    subchildpath:replace_extension ".fx"
    local fxfile = fx_subpath / subchildpath
    fs.create_directories(fxfile:parent_path())

    save_depiction_file(fxfile, fxcontent)

    materialcontent.shader          = nil
    materialcontent.surface_type    = nil
    materialcontent.fx              = to_pkg_path(fxfile):string()
    save_depiction_file(mf, materialcontent)
end

