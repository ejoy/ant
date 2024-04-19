local m = {}
local lfs               = require "bee.filesystem"
m.editor_root = lfs.current_path() / "tools/editor"

local INVALID_PKG_NAMES<const> = {
    ".DS_Store", ".vscode", ".git"
}

local function is_valid_pkg_name(name)
    for _, n in ipairs(INVALID_PKG_NAMES) do
        if n:match(name) then
            return 
        end
    end

    return true
end

local function get_package(entry_path)
    local packages = {}
    local lpath = entry_path / 'pkg'
    for item in lfs.pairs(lpath) do
        local _, pkgname = item:string():match'(.*/)(.*)'
        if is_valid_pkg_name(pkgname) then
            packages[#packages + 1] = {name = pkgname, path = item}
        end
    end
    return packages
end

function m:update_project_root(rootpath)
    if not rootpath then
        return
    end
    local fullpath      = lfs.absolute(rootpath)
    self.project_root   = fullpath
    self.packages       = get_package(fullpath)
end

function m:lpath_to_vpath(lpath)
    return (lfs.path('/') / lfs.relative(lpath, self.project_root)):string()
end

return m