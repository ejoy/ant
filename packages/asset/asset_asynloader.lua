local ecs = ...
local world = ecs.world

local assetmgr = require "asset"

local renderpkg = import_package "ant.render"
local computil = renderpkg.components

local loadlist = ecs.singleton "asyn_load_list"

local function reset_loadlist(ll)
    ll.i = 1
    ll.n = 0
    ll.loaded_assets = nil
    return ll
end

function loadlist.init()
    return reset_loadlist {}
end

local asyn_asset_loader = ecs.system "asyn_asset_loader"
asyn_asset_loader.singleton "asyn_load_list"

local function load_asset(e)
    local rm = e.rendermesh
    if rm.handle == nil then
        computil.create_mesh(rm, e.mesh)
    end

    local material = e.material
    for i=0, #material do
        local m = material[i]
        if m.materialinfo == nil then
            computil.create_material(m)
        end
    end
end

local function start_load_asset(e)
    load_asset(e)
    e.asyn_load = "loading"
end

local function is_mesh_loaded(mesh, rm)
    local m = assetmgr.get_mesh(mesh.ref_path)
    if m then
        return m.handle == rm.handle
    end
    return false
end

local function each_texture(material_properties)
    if properties then
        local textures = properties.textures
        if textures then
            return pairs(textures)
        end
    end
    return next, {}, nil
end

local function is_properties_ready(properties)
    for _, tex in each_texture(properties) do
        if tex.ref_path then
            local t = assetmgr.get_texture(tex.ref_path)
            if t == nil then
                return false
            end
        end
    end

    return true
end

local function is_material_loaded(material)
    --material index start from 0
    for i=0, #material do
        local m = material[i]
        local mi = assetmgr.get_material(m.ref_path)

        if mi == nil then
            return false
        end

        if not (is_properties_ready(mi.properties) 
            and is_properties_ready(m.properties)) then
            return false
        end
    end

    return true
end

local function is_asset_loaded(e)
    if not is_mesh_loaded(e.mesh, e.rendermesh) then
        return false
    end

    return is_material_loaded(e.material)
end

function asyn_asset_loader:post_init()
    local loadlist = self.asyn_load_list
    local loaded_assets = {}
    local max_entity = 5
    for eid in world:each_new "asyn_load" do
        loadlist[loadlist.n+1] = eid
        loadlist.n = loadlist.n+1
    end

    local loadcount = 0
    for i=loadlist.i, loadlist.n do
        local eid = loadlist[i]
        local e = world[eid]
        if e then   -- need check eid is valid
            local loadstate = e.asyn_load
            if loadstate == "" then
                start_load_asset(e)
            elseif loadstate == "loading" then
                if is_asset_loaded(e) then
                    e.asyn_load = "loaded"
                    loaded_assets[#loaded_assets+1] = eid
                end
            else
                assert(loadstate == "loaded")
            end
        end

        loadcount = loadcount + 1
        if max_entity < loadcount then
            break
        end
    end

    local loadnum = #loaded_assets
    if loadnum > 0 then
        loadlist.loaded_assets = loaded_assets
        loadlist.i = loadlist.i + loadnum
        world:update_func "asset_loaded"()
    end

    if loadlist.i > loadlist.n then
        reset_loadlist(loadlist)
    end
    
end