local lfs  = require "filesystem.local"
local fs   = require "filesystem"

return function (filename)
    local output = "/pkg/tools.viewer.prefab_viewer/res/root.glb"
    local loutput = fs.path(output):localpath()
    lfs.create_directories(loutput:parent_path())
    lfs.copy_file(lfs.path(filename), loutput, true)
    return output .. "|mesh.prefab"
end
