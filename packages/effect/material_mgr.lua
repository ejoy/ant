local ecs = ...
local world = ecs.world

local effect    = require "effect"
local assetmgr = import_package "ant.asset"

local ieffect_material_mgr = ecs.interface "ieffect_material_mgr"

local material_indices = {n=0}
local materials = {}
function ieffect_material_mgr.register(key, materialdata)
    local idx = materials[key]
    if idx then
        return idx
    end
    local function find_valid_idx()
        local n = material_indices.n
        for i=1, n do
            if material_indices[i] == nil then
                return i
            end
        end
        n=n+1
        material_indices.n = n
        material_indices[n] = nil
        return n
    end

    local materialidx       = find_valid_idx()
    material_indices[materialidx]  = key
    materials[key]     = materialidx
    effect.register_material(materialidx, materialdata)
    return materialidx
end

function ieffect_material_mgr.get(materialidx)
    return assert(material_indices[materialidx])
end

function ieffect_material_mgr.check_material_indices()
    local indices = effect.valid_material_indices()
    for _, idx in ipairs(indices) do
        local m = material_indices[idx]
        materials[m] = nil
        material_indices[idx] = nil
    end
end