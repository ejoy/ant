local ecs = ...
local world = ecs.world

local assetmgr = require "asset"
local assetutil = require "util"

local fs = require "filesystem"

local resref_counter = ecs.singleton "resource_reference_counter"
function resref_counter.init()
    return {
        unref_resource = {}
    }
end

local assetwatcher = ecs.system "asset_watch_system"
assetwatcher.singleton "resource_reference_counter"
assetwatcher.depend "end_frame"
assetwatcher.dependby "assetgc_system"

function assetwatcher:update()
    local unref_resource = self.resource_reference_counter.unref_resource

    local resource_used = {}
    local function mark_used(reskey)
        local k = assetmgr.res_key(reskey)
        if resource_used[k] == nil then
            resource_used[k] = 1
        else
            resource_used[k] = resource_used[k] + 1
        end

        unref_resource[k] = nil
    end

    for _, eid in world:each "mesh" do
        local e = world[eid]
        local m = e.mesh
        local reskey = m.ref_path
        local res = assetmgr.get_resource(reskey)
        if res then
            mark_used(reskey)
        else
            assert(m.asyn_load)
            assert(e.asyn_load ~= "loaded")
        end
    end

    for _, eid in world:each "rendermesh" do
        local e = world[eid]
        local rm = e.rendermesh
        local reskey = rm.reskey
        if reskey and assetmgr.get_resource(reskey) then
            mark_used(reskey)
        end
    end

    for _, eid in world:each "material" do
        local e = world[eid]
        local m = e.material

        for i=0, #m do
            local mm = m[i]
            local reskey = mm.ref_path
            local matres = assetmgr.get_resource(reskey)
            if matres then
                local shader = matres.shader
                for _, name in ipairs {"vs", "fs", "cs"} do
                    local reskey = shader[name]
                    if reskey and assetmgr.get_resource(reskey) then
                        mark_used(reskey)
                    end
                end
    
                local state = matres.state
                if state.ref_path then
                    local res = assetmgr.get_resource(reskey)
                    if res then
                        mark_used(state.ref_path)
                    end
                end
    
                local function check_texture_ref(properties)
                    for _, tex in assetutil.each_texture(properties) do
                        local reskey = tex.ref_path
                        
                        if assetmgr.get_resource(reskey) then
                            mark_used(reskey)
                        end
                    end
                end
                check_texture_ref(matres.properties)
                check_texture_ref(mm.properties)

                mark_used(reskey)
            else
                assert(m.asyn_load)
                assert(e.asyn_load ~= "loaded")
            end
        end
    end

    for _, eid in world:each "hierarchy" do
        local e = world[eid]
        local hie = e.hierarchy
        local reskey = hie.ref_path
        if reskey then
            if assetmgr.get_resource(reskey) then
                mark_used(reskey)
            end
        end
    end

    for _, eid in world:each "animation" do
        local e = world[eid]
        local ani = e.animation
        local anilist = ani.anilist
        for i=1, #anilist do
            local anielem = anilist[i]
            local reskey = anielem.ref_path
            if assetmgr.get_resource(reskey) then
                mark_used(reskey)
            end
        end
    end

    for _, eid in world:each "skeleton" do
        local ske = world[eid].skeleton
        local reskey = ske.ref_path
        if assetmgr.get_resource(reskey) then
            mark_used(reskey)
        end
    end

    for _, eid in world:each "terrain" do
        local terr = world[eid].terrain
        if assetmgr.get_resource(terr.ref_path) then
            mark_used(terr.ref_path)
        end
    end

    for _, eid in world:each "skinning_mesh" do
        local sm = world[eid].skinning_mesh
        if assetmgr.get_resource(sm.ref_path) then
            mark_used(sm.ref_path)
        end
    end

    local function mark_unref(reskey)
        local ref = unref_resource[reskey]
        if ref == nil then
            unref_resource[reskey] = {
                check_count = 1
            }
        else
            ref.check_count = ref.check_count + 1
        end
    end

    local resources = assetmgr.get_all_resources()
    for key, res in pairs(resources) do
        if resource_used[key] == nil then
            mark_unref(key)
        end
    end
end

local assetgc = ecs.system "assetgc_system"
assetgc.singleton "resource_reference_counter"

function assetgc:update()
    local unref_resource = self.resource_reference_counter.unref_resource

    for reskey, v in pairs(unref_resource) do
        assetmgr.unload(fs.path(reskey))
        unref_resource[reskey] = nil
    end
end