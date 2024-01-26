local m = {}
local fs                = require "filesystem"
local lfs               = require "bee.filesystem"
local vfs               = require "vfs"
local access            = require "common.vfs_access"
m.repo_access = access
m.editor_root = lfs.path(vfs.repopath())

local function get_package(entry_path, readmount)
    local repo = {_root = entry_path}
    if readmount then
        access.readmount(repo)
    end
    local packages = {}
    for _, value in ipairs(repo._mountlpath) do
        local strvalue = value:string()
        if strvalue:sub(-7) == '/engine' then
            goto continue
        end
        if strvalue:sub(-4) ~= '/pkg' then
            value = value / 'pkg'
        end
        for item in lfs.pairs(value) do
            local _, pkgname = item:string():match'(.*/)(.*)'
            local skip = false
            if pkgname:sub(1, 4) == "ant." and pkgname:sub(1, 8) ~= "ant.test" then
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
    return packages
end

function m:update_project_root(rootpath)
    if not rootpath then
        return
    end
    local fullpath      = lfs.absolute(rootpath)
    self.project_root   = fullpath
    self.packages       = get_package(fullpath, true)
end

function m:lpath_to_vpath(lpath)
    return self.virtual_prefab_path:string() .. "/" .. lfs.relative(lpath, self.current_compile_path):string()
end

return m