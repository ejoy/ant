local ecs = ...
local world = ecs.world

local assetmgr = require "asset"

local renderpkg = import_package "ant.render"
local computil = renderpkg.components

local loadlist = ecs.singleton "asyn_load_list"

local function reset_loadlist(ll)
    ll.i = 1
    ll.n = 0
end

function loadlist.init()
    local t = {}
    reset_loadlist(t)
    return t
end

local asyn_asset_loader = ecs.system "asyn_asset_loader"
asyn_asset_loader.singleton "asyn_load_list"

local function load_asset(e)
    local mesh = e.mesh
    do
        assert(mesh.asyn_load)
        mesh.assetinfo = assetmgr.load(assert(mesh.ref_path))
        computil.transmit_mesh(mesh, e.rendermesh)
    end

    local materials = e.material
    do
        for _, material in ipairs(materials) do
            assert(material.asyn_load)
            computil.create_material(material)
        end
    end

    e.asyn_load = "loaded"
end

function asyn_asset_loader:post_init()
    local loadlist = self.asyn_load_list
    
    local loaded_assets = {}
    local max_entity = 5
    for eid in world:each_new "asyn_load" do
        loadlist[loadlist.n+1] = eid
        loadlist.n = loadlist.n+1
    end

    for i=loadlist.i, loadlist.n do
        local eid = loadlist[i]
        local e = world[eid]
        if e then   -- need check eid is valid
            load_asset(e)
            loaded_assets[#loaded_assets+1] = eid

            --print("loaded entity:", eid, e.name or "")
            if max_entity < #loaded_assets then
                --print("---------------------------")
                break
            end
        end
    end

    local loadnum = #loaded_assets
    if loadnum > 0 then
        loadlist.i = loadlist.i + loadnum
        world:update_func "asset_loaded"()
    end

    if loadlist.i == loadlist.n then
        reset_loadlist(loadlist)
    end
    
end