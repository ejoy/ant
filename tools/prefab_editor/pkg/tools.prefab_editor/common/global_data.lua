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

local function get_package(entry_path, readmount)
    local repo = {_root = entry_path}
    if readmount then
        access.readmount(repo)
    end
    local packages = {}
    for _, name in ipairs(repo._mountname) do
        if #name > 1 then
            vfs.mount(name, repo._mountpoint[name]:string())
            if not (name:match "/pkg/ant%." and skip_package(name)) then
                packages[#packages + 1] = {name = name, path = repo._mountpoint[name]}
            end
        end
    end
    m.repo = repo
    return packages
end

function m:update_root(rootpath)
    self.project_root   = lfs.path(rootpath)
    self.packages       = get_package(lfs.absolute(self.project_root:string()), true)
    self.package_path   = fs.path(find_package_name(rootpath, self.packages))
    return self.package_path
end

return m