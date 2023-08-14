local ecs   = ...
local world = ecs.world
local w     = world.w
local idrawindirect = ecs.import.interface "ant.render|idrawindirect"
local setting       = import_package "ant.settings".setting
local renderutil    = require "util"
local queuemgr      = require "queue_mgr"
local s             = ecs.system "pre_depth_system"
local math3d        = require "math3d"
local R             = ecs.clibs "render.render_material"

if setting:get "graphic/disable_pre_z" then
    renderutil.default_system(s, "init", "data_changed", "update_filter")
    return 
end

local irender   = ecs.require "ant.render|render_system.render"
local irq       = ecs.require "ant.render|render_system.renderqueue"
local imaterial = ecs.require "ant.asset|material"
local irl       = ecs.import.interface "ant.render|irender_layer"

local pre_depth_material
local pre_depth_skinning_material
local pre_depth_indirect_material

local function which_material(skinning, indirect)
    if indirect then
       return pre_depth_indirect_material.object

    end
    if skinning then
        return pre_depth_skinning_material.object
    end

    return pre_depth_material.object
end

function s:init()
    pre_depth_material 			= imaterial.load_res "/pkg/ant.resources/materials/predepth.material"
    pre_depth_indirect_material = imaterial.load_res "/pkg/ant.resources/materials/predepth_indirect.material"
    pre_depth_skinning_material = imaterial.load_res "/pkg/ant.resources/materials/predepth_skin.material"
end

local vr_mb = world:sub{"view_rect_changed", "main_queue"}
local vp_changed_mb = world:sub{"world_viewport_changed"}
local mc_mb = world:sub{"main_queue", "camera_changed"}
function s:data_changed()
    for _, _, vr in vr_mb:unpack() do
        irq.set_view_rect("pre_depth_queue", vr)
    end

    for _, vp in vp_changed_mb:unpack() do
        irq.set_view_rect("pre_depth_queue", vp)
    end

    for _, _, ceid in mc_mb:unpack() do
        local e = w:first "pre_depth_queue camera_ref:out"
        e.camera_ref = ceid
        w:submit(e)
    end
end

local function create_depth_only_material(mo, fm)
    local newstate = irender.check_set_state(mo, fm.main_queue, function (d, s)
        d.PT, d.CULL = s.PT, s.CULL
        d.DEPTH_TEST = "GREATER"
        return d
    end)

    local mi = mo:instance()
    mi:set_state(newstate)
    return mi
end

function s:update_filter()
    for e in w:select "filter_result visible_state:in render_layer:in render_object:update filter_material:in skinning?in indirect?in" do
        if e.visible_state["pre_depth_queue"] and irl.is_opacity_layer(e.render_layer) then
            local mo = assert(which_material(e.skinning, e.indirect))
            local ro = e.render_object
            local fm = e.filter_material
            local mi = create_depth_only_material(mo, fm)
            if e.indirect then
				local draw_indirect_type = idrawindirect.get_draw_indirect_type(e.indirect)
				mi.u_draw_indirect_type = math3d.vector(draw_indirect_type)
			end
            fm["pre_depth_queue"] = mi
            R.set(ro.rm_idx, queuemgr.material_index "pre_depth_queue", mi:ptr())
        end
    end
end
