local require = import and import(...) or require
local rawtable = require "rawtable"
local mesh_util = require "render.resources.mesh_util"

return function (filename)
    local mesh = rawtable(filename)
    local mesh_path = mesh.mesh_path
    assert(mesh_path ~= nil)
    
    if #mesh_path ~= 0 then
        mesh.handle = mesh_util.meshLoad(mesh_path)
    end
    
    return mesh
end
