local m = {}
local lfs               = require "bee.filesystem"
m.editor_root = lfs.current_path() / "tools/editor"

local function get_package(entry_path)
    local packages = {}
    local lpath = entry_path / 'pkg'
    for item in lfs.pairs(lpath) do
        local _, pkgname = item:string():match'(.*/)(.*)'
        packages[#packages + 1] = {name = pkgname, path = item}
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
    -- return (self.virtual_glb_path / lfs.relative(lpath, self.current_compile_path)):string()
    return (lfs.path('/') / lfs.relative(lpath, self.project_root)):string()
end

return m