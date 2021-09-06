local ecs = ...
local world = ecs.world
local w = world.w

local imaterial = world:interface "ant.asset|imaterial"
local assetmgr = import_package "ant.asset"

local lm_sys = ecs.system "lightmap_system"

local default_lm
function lm_sys:init()
    default_lm = assetmgr.resource "/pkg/ant.resources/textures/default.texture"
end

local function update_lm_texture(properties, handle)
    imaterial.set_property_directly(properties, "s_lightmap", {stage=8, texture={handle=handle}})
end

--TODO: need remove
local lm_result_mb = world:sub{"component_register", "lightmap_result"}

function lm_sys:entity_init()
    for msg in lm_result_mb:each() do
        local eid = msg[3]
        local lmr_e = world[eid]
        local r = lmr_e.lightmap_result
        for e in w:select "lightmap:in render_object:in filter_material:in" do
            local lm = e.lightmap
            local lmid = lm.id
            local bi = r[lmid]
            if bi then
                bi.texture = assetmgr.resource(bi.texture_path)
                for _, fm in pairs(e.filter_material) do
                    update_lm_texture(fm.properties, bi.texture_path)
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
    return imaterial.load(mf, s)
end

function lm_sys:end_filter()
    for e in w:select "filter_result:in lightmap:in render_object:in filter_material:in material:in" do
        --local lr_e = w:singleton("lightmapper", "lightmap_result:in")
        local lr_e
        for _, eid in world:each "lightmap_result" do
            lr_e = world[eid]
            break
        end

        local r = lr_e and lr_e.lightmap_result or {}
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