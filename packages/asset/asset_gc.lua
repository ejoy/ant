local ecs = ...
local world = ecs.world

local assetmgr = require "asset"
local assetutil = require "util"

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
        assert(assetmgr.get_resource(reskey))
        mark_used(reskey)
    end

    for _, eid in world:each "rendermesh" do
        local e = world[eid]
        local rm = e.rendermesh
        local reskey = rm.reskey
        assert(assetmgr.get_resource(reskey))
        mark_used(reskey)
    end

    for _, eid in world:each "material" do
        local e = world[eid]
        local m = e.material

        for i=0, #m do
            local mm = m[i]
            local reskey = mm.ref_path
            local matres = assert(assetmgr.get_resource(reskey))

            local shader = matres.shader
            for _, name in ipairs {"vs", "fs", "cs"} do
                local reskey = shader[name]
                if reskey then
                    mark_used(reskey)
                end
            end

            local state = matres.state
            if state.ref_path then
                mark_used(state.ref_path)
            end

            for _, pp in ipairs {matres.properties, mm.properties} do
                for _, tex in assetutil.each_texture(pp) do
                    local reskey = tex.ref_path
                    assert(assetmgr.get_resource(reskey))
                    mark_used(reskey)
                end
            end

            mark_used(reskey)
        end
    end

    for _, eid in world:each "hierarchy" do
        local e = world[eid]
        local hie = e.hierarchy
        local reskey = hie.ref_path
        if reskey then
            assert(assetmgr.get_resource(reskey))

            mark_used(reskey)
        end
    end

    for _, eid in world:each "animation" do
        local e = world[eid]
        local ani = e.animation
        local anilist = ani.anilist
        for i=1, #anilist do
            local anielem = anilist[i]
            local reskey = anielem.ref_path
            assert(assetmgr.get_resource(reskey))
            mark_used(reskey)
        end
    end

    for _, eid in world:each "skeleton" do
        local ske = world[eid].skeleton
        local reskey = ske.ref_path
        assert(assetmgr.get_resource(reskey))
        mark_used(reskey)
    end

    for _, eid in world:each "terrain" do
        local terr = world[eid].terrain
        mark_used(terr.ref_path)
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

    for i=1, #unref_resource do
        local reskey = unref_resource[i]
        assetmgr.unload(reskey)
    end
end