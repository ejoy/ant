local m = {}
local fs                = require "filesystem"
local lfs               = require "filesystem.local"
local vfs               = require "vfs"
local access            = dofile "/engine/vfs/repoaccess.lua"
m.repo_access = access

m.editor_root           = lfs.path(fs.path "":localpath())

local function find_package_name(proj_path, packages)
    for _, pkg in ipairs(packages) do
        if pkg.path == proj_path then
            return pkg.name
        end
    end
end

local NOT_skip_packages = {
    "ant.resources",
    "ant.resources.binary",
    "ant.test.feature",
}

local function skip_package(pkgpath)
    for _, n in ipairs(NOT_skip_packages) do
        if pkgpath:match(n) then
            return false
        end
    end
    return true
end

local function has_pkg(path)
    for item in lfs.pairs(path) do
        if string.sub(tostring(item), -4) == '/pkg' then
            return true
        end
    end
    return false
end
local function get_package(entry_path, readmount)
    local repo = {_root = entry_path}
    if readmount then
        access.readmount(repo)
    end
    local packages = {}
    for _, value in ipairs(repo._mountpoint) do
        if not has_pkg(value) then
            goto continue
        end
        local pkgpath = value / "pkg"
        if value:string() == "./" then
            for item in lfs.pairs(pkgpath) do
                local _, pkgname = item:string():match'(.*/)(.*)'
                if pkgname == "ant.resources" or pkgname == "ant.resources.binary" then
                    packages[#packages + 1] = {name = pkgname, path = item}
                end
            end
        else
            for item in lfs.pairs(pkgpath) do
                local _, pkgname = item:string():match'(.*/)(.*)'
                packages[#packages + 1] = {name = pkgname, path = item}
            end
        end
        ::continue::
    end
    m.repo = repo
    vfs.mount(entry_path:string())
    return packages
end

function m:update_root(rootpath)
    self.project_root   = lfs.path(rootpath)
    self.packages       = get_package(lfs.absolute(self.project_root:string()), true)
    self.package_path   = fs.path(find_package_name(rootpath, self.packages))
    return self.package_path
end

return m