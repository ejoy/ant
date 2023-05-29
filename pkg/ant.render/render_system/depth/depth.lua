local ecs   = ...
local world = ecs.world
local w     = world.w

local setting       = import_package "ant.settings".setting
local renderutil    = require "util"
local s             = ecs.system "pre_depth_system"

local rendercore    = ecs.clibs "render.core"

if setting:get "graphic/disable_pre_z" then
    renderutil.default_system(s, "init", "data_changed", "update_filter")
    return 
end

local irender   = ecs.import.interface "ant.render|irender"
local irq       = ecs.import.interface "ant.render|irenderqueue"
local imaterial = ecs.import.interface "ant.asset|imaterial"

local pre_depth_material
local pre_depth_skinning_material
local pre_depth_heap_material
local pre_depth_indirect_material
local pre_depth_road_material
local pre_depth_sm_material


local function which_material(skinning, heapmesh, indirect)
    if heapmesh then
        return pre_depth_heap_material.object
    end
    if indirect then
        if indirect.type == "ROAD" then
            return pre_depth_road_material.object
        elseif indirect.type == "STONEMOUNTAIN" then
            return pre_depth_sm_material.object
        else
            return pre_depth_indirect_material.object
        end
    end
    if skinning then
        return pre_depth_skinning_material.object
    end

    return pre_depth_material.object
end

function s:init()
    pre_depth_material 			= imaterial.load_res "/pkg/ant.resources/materials/predepth.material"
    pre_depth_heap_material     = imaterial.load_res "/pkg/ant.resources/materials/predepth_heap.material"
    pre_depth_indirect_material = imaterial.load_res "/pkg/ant.resources/materials/predepth_indirect.material"
    pre_depth_skinning_material = imaterial.load_res "/pkg/ant.resources/materials/predepth_skin.material"
    pre_depth_road_material     = imaterial.load_res "/pkg/ant.resources/materials/predepth_road.material"
    pre_depth_sm_material       = imaterial.load_res "/pkg/ant.resources/materials/predepth_sm.material"
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

local function create_depth_only_material(mo, fm)
    local newstate = irender.check_set_state(mo, fm.main_queue:get_material(), function (d, s)
        d.PT, d.CULL = s.PT, s.CULL
        d.DEPTH_TEST = "GREATER"
        return d
    end)

    local mi = mo:instance()
    mi:set_state(newstate)
    return mi
end

function s:update_filter()
    for e in w:select "filter_result pre_depth_queue_visible:update render_layer:in render_object:update filter_material:in skinning?in heapmesh?in indirect?in" do
        if e.render_layer == "opacity" then
            local mo = assert(which_material(e.skinning, e.heapmesh, e.indirect))
            local ro = e.render_object
            local fm = e.filter_material

            local mi = create_depth_only_material(mo, fm)
            fm["pre_depth_queue"] = mi
            rendercore.rm_set(ro.rm_idx, irender.material_index "pre_depth_queue", mi:ptr())
        else
            e.pre_depth_queue_visible = nil
        end
        -- fm["scene_depth_queue"] = mi
        -- ro.mat_scenedepth = h
        --e["scene_depth_queue_visible"] = true
    end
end
