local ecs   = ...
local world = ecs.world
local w     = world.w


local setting       = import_package "ant.settings"
local renderutil    = require "util"

local s             = ecs.system "pre_depth_system"
if setting:get "graphic/disable_pre_z" then
    renderutil.default_system(s, "init", "data_changed", "update_filter")
    return 
end

local bgfx          = require "bgfx"
local idrawindirect = ecs.require "ant.render|draw_indirect_system"
local queuemgr      = ecs.require "queue_mgr"

local math3d        = require "math3d"
local R             = world:clibs "render.render_material"
local RM            = ecs.require "ant.material|material"

local irq           = ecs.require "ant.render|render_system.renderqueue"
local irl           = ecs.require "ant.render|render_layer"

local assetmgr      = import_package "ant.asset"

local pre_depth_material
local pre_depth_skinning_material
local pre_depth_indirect_material

local function which_material(skinning, indirect)
    if indirect then
       return pre_depth_indirect_material

    end
    if skinning then
        return pre_depth_skinning_material
    end

    return pre_depth_material
end

function s:init()
    pre_depth_material 			= assetmgr.resource "/pkg/ant.resources/materials/predepth.material"
    pre_depth_indirect_material = assetmgr.resource "/pkg/ant.resources/materials/predepth_indirect.material"
    pre_depth_skinning_material = assetmgr.resource "/pkg/ant.resources/materials/predepth_skin.material"
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

local NO_DEPTH_TEST_STATES<const> = {
    NEVER = true, ALWAYS = true, NONE = true
}

local function has_depth_test(dt)
    if dt then
        return not NO_DEPTH_TEST_STATES[dt]
    end
    return false
end

local function create_depth_state(srcstate, dststate)
    local s = bgfx.parse_state(srcstate)
    if has_depth_test(s.DEPTH_TEST) then
        local d = bgfx.parse_state(dststate)
        d.PT, d.CULL = s.PT, s.CULL
        d.DEPTH_TEST = "GREATER"
        return bgfx.make_state(d)
    end
end

function s:update_filter()
    for e in w:select "filter_result visible_state:in material:in render_layer:in render_object:update filter_material:in skinning?in indirect?in" do
        if e.visible_state["pre_depth_queue"] and irl.is_opacity_layer(e.render_layer) then
            local matres = assetmgr.resource(e.material)
            if not matres.fx.setting.no_predepth then
                local fm = e.filter_material
                local m = assert(which_material(e.skinning, e.indirect))
                local newstate = create_depth_state(fm.main_queue:get_state(), m.state)
                if newstate then
                    local mi = RM.create_instance(m.object)
                    mi:set_state(newstate)
    
                    if e.indirect then
                        local draw_indirect_type = idrawindirect.get_draw_indirect_type(e.indirect)
                        mi.u_draw_indirect_type = math3d.vector(draw_indirect_type)
                    end
                    fm["pre_depth_queue"] = mi
                    R.set(e.render_object.rm_idx, queuemgr.material_index "pre_depth_queue", mi:ptr())
                end
            end
        end
    end
end
