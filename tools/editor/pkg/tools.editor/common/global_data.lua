local m = {}
local fs                = require "filesystem"
local lfs               = require "bee.filesystem"
local vfs               = require "vfs"
local access            = dofile "/engine/editor/vfs_access.lua"
m.repo_access = access

m.editor_root           = lfs.path(vfs.repopath())

local function find_package_name(proj_path, packages)
    for _, pkg in ipairs(packages) do
        if pkg.path == proj_path then
            return pkg.name
        end
    end
end

local function get_package(entry_path, readmount)
    local repo = {_root = entry_path}
    if readmount then
        access.readmount(repo)
    end
    local packages = {}
    for _, value in ipairs(repo._mountlpath) do
        if string.sub(tostring(value), -7) == '/engine' then
            goto continue
        end
        if string.sub(tostring(value), -4) ~= '/pkg' then
            value = value / 'pkg'
        end
        for item in lfs.pairs(value) do
            local _, pkgname = item:string():match'(.*/)(.*)'
            local skip = false
            if string.sub(pkgname, 1, 4) == "ant." then
                if not (pkgname == "ant.resources" or pkgname == "ant.resources.binary") then
                    skip = true
                end
            end
            if not skip then
                packages[#packages + 1] = {name = pkgname, path = item}
            end
        end
        ::continue::
    end
    m.repo = repo
    --vfs.mount(entry_path:string())
    return packages
end

function m:update_project_root(rootpath)
    if not rootpath then
        return
    end
    self.project_root   = lfs.path(rootpath)
    self.packages       = get_package(lfs.absolute(self.project_root:string()), true)
    self.package_path   = fs.path(find_package_name(rootpath, self.packages))
    return self.package_path
end

function m:lpath_to_vpath(lpath)
    return self.virtual_prefab_path:string() .. "/" .. lfs.relative(lpath, self.current_compile_path):string()
end

return m