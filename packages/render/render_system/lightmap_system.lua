local ecs = ...
local world = ecs.world
local w = world.w

local imaterial = world:interface "ant.asset|imaterial"
local assetmgr = import_package "ant.asset"

local lm_sys = ecs.system "lightmap_system"

function lm_sys:entity_init()
    for e in w:select "INIT lightmap_result:in" do
        local lmr = e.lightmap_result
        for _, bi in pairs(lmr) do
            bi.texture = assetmgr.resource(bi.texture)
        end
    end
end

local function get_baked_material(mf, setting)
    local s = {USE_BAKED=1}
    for k, v in pairs(setting) do
        s[k] = v
    end
    return imaterial.load(mf, s)
end

function lm_sys:end_filter()
    for e in w:select "filter_result:in lightmap:in render_object:in filter_material:in material:in" do
        local lr_e = w:singleton "lightmap_result"
        local r = lr_e.lightmap_result
        local mq = w:singleton("main_queue", "filter_names")
        local fr = e.filter_result
        local material = e.material
        for _, fn in ipairs(mq.filter_names) do
            if fr[fn] then
                local fm = e.filter_material
                local lm = e.lightmap
                local bakeid = lm.bake_id
                local bi = r[bakeid]
                if bi then
                    local mf = material._data and tostring(material) or material
                    local bm = get_baked_material(mf, material.fx.setting)
                    local pm = bm.properties["s_lightmap"]
                    pm.texture.handle = bi.texture.handle
                    fm[fn] = {
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