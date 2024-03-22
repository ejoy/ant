local ecs   = ...
local world = ecs.world
local w     = world.w

local setting       = import_package "ant.settings"
local s             = ecs.system "pre_depth_system"
if setting:get "graphic/disable_pre_z" then
    return
end

local ivm           = ecs.require "ant.render|visible_mask"
local irender       = ecs.require "ant.render|render"
local queuemgr      = ecs.require "queue_mgr"

local R             = world:clibs "render.render_material"
local RM            = ecs.require "ant.material|material"

local irq           = ecs.require "ant.render|renderqueue"
local irl		    = ecs.require "ant.render|render_layer.render_layer"

local featureset    = require "feature_set"

local assetmgr      = import_package "ant.asset"

local FEATURE_MATERIALS = {}

local function which_material(e, matres)
    if matres.fx.depth then
        return matres
    end
    w:extend(e, "feature_set:in")
    local flag = featureset.flag_from_featureset(e.feature_set)
    return assert(FEATURE_MATERIALS[flag], "Invalid featureset")
end

function s:init()
    FEATURE_MATERIALS[featureset.flag ""]               = assetmgr.resource "/pkg/ant.resources/materials/predepth.material"
    FEATURE_MATERIALS[featureset.flag "GPU_SKINNING"]   = assetmgr.resource "/pkg/ant.resources/materials/predepth_skin.material"
    FEATURE_MATERIALS[featureset.flag "DRAW_INDIRECT"]  = assetmgr.resource "/pkg/ant.resources/materials/predepth_di.material"
end

local vr_mb = world:sub{"view_rect_changed", "main_queue"}
local mc_mb = world:sub{"main_queue", "camera_changed"}
function s:data_changed()
    for _, _, vr in vr_mb:unpack() do
        irq.set_view_rect("pre_depth_queue", vr)
    end

    for _, _, ceid in mc_mb:unpack() do
        local e = w:first "pre_depth_queue camera_ref:out"
        e.camera_ref = ceid
        w:submit(e)
    end
end

function s:entity_ready()
    for e in w:select "filter_result render_object:update render_layer:in material:in" do
        if ivm.check(e, "pre_depth_queue") and irl.is_opacity_layer(e.render_layer) then
            w:extend(e, "material:in filter_material:in")
            local matres = assetmgr.resource(e.material)
            if not matres.fx.setting.no_predepth then
                local fm = e.filter_material
                local m = which_material(e, matres)
                local Dmi = fm.DEFAULT_MATERIAL
                local newstate = irender.create_depth_state(Dmi:get_state())
                if newstate then
                    local mi = RM.create_instance(m.depth.object)
                    mi:set_state(newstate)

                    local midx = queuemgr.material_index "pre_depth_queue"
                    fm[midx] = mi
                    R.set(e.render_object.rm_idx, midx, mi:ptr())
                end
            end
        end
    end
end
