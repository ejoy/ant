local ecs = ...
local world = ecs

local assetmgr = require "asset"

local renderpkg = import_package "ant.render"
local computil = renderpkg.util

local asyn_asset_loader = ecs.system "asyn_asset_loader"

function asyn_asset_loader.update()
    local loaded_assets = {}
    for _, eid in world:each "asyn_load" do
        local e = world[eid]
        local mesh = e.mesh
        do
            assert(mesh.asyn_load)
            mesh.assetinfo = assetmgr.load(assert(mesh.ref_path))
            computil.transmit_mesh(e.rendermesh, mesh)
        end

        local materials = e.material
        do
            for _, material in ipairs(materials) do
                assert(material.asyn_load)
                computil.create_material(material)
            end
        end
        
        loaded_assets[#loaded_assets+1] = eid
    end

    if #loaded_assets > 0 then
        for _, eid in ipairs(loaded_assets) do
            world:remove_component(eid, "asset_post_load")
        end
        world:update_func "asset_loaded"()
    end
    
end