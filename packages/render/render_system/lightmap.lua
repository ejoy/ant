local ecs = ...
local world = ecs.world
local w = world.w

local imaterial = ecs.import.interface "ant.asset|imaterial"
local assetmgr = import_package "ant.asset"

local lm_mount = ecs.action "lightmap_mount"

local function apply_lightmap(prefab, lm_prefab, sidx, eidx)
    for i=sidx, eidx do
        if type(prefab[i]) == "table" then
            apply_lightmap(prefab[i], assert(lm_prefab[i].prefab), 1, #prefab[i])
        else
            local eid = prefab[i]
            local e = world[eid]
            local lm  = lm_prefab[i].lightmap
            if lm then
                e.lightmap = lm
            end
        end
    end
end

local function build_lightmap_cache(lmr_e)
    local lmr = lmr_e.lightmap_result

    local function build_(prefab, cache)
        for _, e in ipairs(prefab) do
            if e.prefab then
                build_(e.prefab, cache)
            else
                local lm = e.lightmap
                if lm then
                    cache[lm.id] = lm
                end
            end
        end
    end

    local c = {}
    build_(lmr, c)
    lmr_e.lightmap_cache = c
end
function lm_mount.init(prefab, idx, value)
    local lmr_prefab = prefab[idx]
    assert(#lmr_prefab == 1)
    local lmr_e = world[lmr_prefab[1]]
    assert(#prefab == idx)
    apply_lightmap(prefab, lmr_e.lightmap_result, 1, idx-1)
    build_lightmap_cache(lmr_e)
end

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
        for e in w:select "lightmap:in render_object:in filter_material:in" do
            local lm = e.lightmap
            local lmid = lm.id
            local bi = c[lmid]
            if bi then
                bi.texture = assetmgr.resource(bi.texture_path)
                for _, fm in pairs(e.filter_material) do
                    fm.material.s_lightmap = bi.texture.handle
                end
            end
        end
    end
end

local function load_lightmap_material(mf, setting)
    local s = {USING_LIGHTMAP=1}
    for k, v in pairs(setting) do
        s[k] = v
    end
    s["ENABLE_SHADOW"] = nil
    s["identity"] = nil
    s['shadow_cast'] = 'off'
    s['shadow_receive'] = 'off'
    s['skinning'] = 'UNKNOWN'
    s['bloom'] = 'off'
    s['ENABLE_IBL'] = 'off'
    return imaterial.load(mf, s)
end

function lm_sys:end_filter()
    for e in w:select "filter_result:in lightmap:in render_object:in filter_material:in material:in" do
        local lr_e = w:singleton("lightmapper", "lightmap_result:in")

        local r = lr_e and lr_e.lightmap_cache or {}
        local mq = w:singleton("main_queue", "primitive_filter:in")
        local fr = e.filter_result
        local material = e.material
        for _, fn in ipairs(mq.primitive_filter) do
            if fr[fn] then
                local lm = e.lightmap
                local lmid = lm.id

                local mf = type(material) == "string" and material or tostring(material)
                local bm = load_lightmap_material(mf, material.fx.setting)

                local bi = r[lmid]

                local lmhandle
                if bi then
                    bi.texture = assetmgr.resource(bi.texture_path)
                    lmhandle = bi.texture.handle
                else
                    lmhandle = default_lm.handle
                end

                update_lm_texture(bm.properties, lmhandle)

                e.filter_material[fn] = {
                    fx          = bm.fx,
                    properties  = bm.properties,
                    state       = bm.state,
                    stencil     = bm.stencil,
                }
            end
        end
    end
end