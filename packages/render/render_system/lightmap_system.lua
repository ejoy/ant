local ecs = ...
local world = ecs.world
local w = world.w

local imaterial = world:interface "ant.asset|imaterial"
local assetmgr = import_package "ant.asset"

local lm_sys = ecs.system "lightmap_system"

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
        local lr_e = w:singleton("lightmapper", "lightmap_result:in")
        local r = lr_e.lightmap_result
        local mq = w:singleton("main_queue", "primitive_filter:in")
        local fr = e.filter_result
        local material = e.material
        for _, fn in ipairs(mq.primitive_filter) do
            if fr[fn] then
                
                local lm = e.lightmap
                local bakeid = lm.bake_id
                local bi = r[bakeid]
                if bi then
                    bi.texture = assetmgr.resource(bi.texture_path)
                    local mf = type(material) == "string" and material or tostring(material)
                    local bm = load_lightmap_material(mf, material.fx.setting)
                    imaterial.set_property_directly(bm.properties, "s_lightmap", {stage=8, texture={handle=bi.texture.handle}})
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
end