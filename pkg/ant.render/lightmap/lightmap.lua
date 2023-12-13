local ecs = ...
local world = ecs.world
local w = world.w

local imaterial = ecs.require "ant.asset|material"
local assetmgr = import_package "ant.asset"

local lm_sys = ecs.system "lightmap_system"

local default_lm
function lm_sys:init()
    default_lm = assetmgr.resource "/pkg/ant.resources/textures/black.texture"
end

local function update_lm_texture(material, handle)
    
end

function lm_sys:entity_init()
    for lmr_e in w:select "INIT lightmap_result:in" do
        local c = lmr_e.lightmap_result.cache
        for e in w:select "lightmap:in filter_material:in" do
            local lm = e.lightmap
            local lmid = lm.id
            local bi = c[lmid]
            if bi then
                bi.texture = assetmgr.resource(bi.texture_path)
                local m = e.fitler_material.main_queue
                m.s_lightmap = bi.texture.handle
            end
        end
    end
end

local function load_lightmap_material(mf, setting)
    -- local s = {USING_LIGHTMAP=1}
    -- for k, v in pairs(setting) do
    --     s[k] = v
    -- end
    -- s["ENABLE_SHADOW"] = nil
    -- s["identity"] = nil
    -- s['cast_shadow'] = 'off'
    -- s['receive_shadow'] = 'off'
    -- s['skinning'] = 'UNKNOWN'
    -- s['bloom'] = 'off'
    -- s['ENABLE_IBL'] = 'off'

    local newmf = nil   --TODO
    return assetmgr.resource(newmf)
end

function lm_sys:update_filter()
    assert(false, "Invalid code")
    for e in w:select "filter_result lightmap:in render_object:update material:in" do
        local lr_e = w:first("lightmapper lightmap_result:in")

        local r = lr_e and lr_e.lightmap_cache or {}
        local matpath = e.material
        local matres = assetmgr.resource(e.material)

        local lm = e.lightmap
        local lmid = lm.id

        local bm = load_lightmap_material(matpath, matres.fx.setting)

        local bi = r[lmid]

        local lmhandle
        if bi then
            bi.texture = assetmgr.resource(bi.texture_path)
            lmhandle = bi.texture.handle
        else
            lmhandle = default_lm.handle
        end

        local new_mi = bm:material()
        new_mi.s_lightmap = lmhandle
        local qm = imaterial.get_materials(e.render_object)
        qm:set("main_queue", new_mi)
    end
end