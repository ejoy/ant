local require = import and import(...) or require
local rawtable = require "rawtable"
local path = require "filesystem.path"
local util = require "util"

return function(filename, assetmgr)
    local assetmgr = require "asset"

    local render = assert(rawtable(filename))
    local mesh = assetmgr.load(render.mesh_name)
    
    local binding = render.binding
    local binding_info = {}
    for _, v in ipairs(binding) do
        local material = assetmgr.load(v.material_name)
        local groupids = v.mesh_groupids
        for _, id in ipairs(groupids) do
            local mgroups = mesh.handle.group
            if mgroups[id] == nil then
                error(string.format("id = %d not exist in mesh groups. in render file : %s", id, filename))
            end
        end

        table.insert(binding_info, {material= material, groupids=groupids})        
    end

    return { mesh = mesh, binding = binding_info }
end