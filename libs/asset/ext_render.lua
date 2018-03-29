local require = import and import(...) or require
local rawtable = require "rawtable"
local path = require "filesystem.path"
local util = require "util"

local render_metatable = {}
render_metatable.__index = render_metatable
function render_metatable:get_material(b_idx)
    local bindings = self.binding
    local bnum = #bindings
    assert(bnum >= b_idx)
    return bindings[b_idx].material
end

function render_metatable:get_uniform(b_idx, uname)
    local material = self:get_material(b_idx)
    local uniform = material.uniform
    if uniform then
        local defines = uniform.defines
        return defines and defines[uname] or nil
    end

    return nil
end

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

    return setmetatable({ mesh = mesh, binding = binding_info },
                        render_metatable)
end