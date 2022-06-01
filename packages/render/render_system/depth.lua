local ecs = ...
local world = ecs.world

local mu = import_package "ant.math".util

local fbmgr = require "framebuffer_mgr"
local viewidmgr = require "viewid_mgr"
local sampler = require "sampler"

local irender   = ecs.import.interface "ant.render|irender"
local irq       = ecs.import.interface "ant.render|irenderqueue"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local ifs       = ecs.import.interface "ant.scene|ifilter_state"
local bgfx      = require "bgfx"

local pre_depth_material
local pre_depth_skinning_material

local function which_material(skinning)
	return skinning and pre_depth_skinning_material or pre_depth_material
end


local s = ecs.system "pre_depth_primitive_system"
local w = world.w

function s:init()
    if not irender.use_pre_depth() then
        return
    end

    local pre_depth_material_file<const> 	= "/pkg/ant.resources/materials/predepth.material"
    pre_depth_material 			= imaterial.load(pre_depth_material_file, {depth_type="inv_z"})
    pre_depth_skinning_material = imaterial.load(pre_depth_material_file, {depth_type="inv_z", skinning="GPU"})
end

local function check_set_pre_depth_state(state)
    local ss = bgfx.parse_state(state)
    ss.WRITE_MASK = "Z"
    return bgfx.make_state(ss)
end

local vr_mb = world:sub{"view_rect_changed", "main_queue"}
local mc_mb = world:sub{"main_queue", "camera_changed"}
function s:data_changed()
    if irender.use_pre_depth() then
        for msg in vr_mb:each() do
            local vr = msg[3]
            local dq = w:singleton("pre_depth_queue", "render_target:in")
            local dqvr = dq.render_target.view_rect
            --have been changed in viewport detect
            assert(vr.w == dqvr.w and vr.h == dqvr.h)
            if vr.x ~= dqvr.x or vr.y ~= dqvr.y then
                irq.set_view_rect("pre_depth_queue", vr)
                irq.set_view_rect("scene_depth_queue", vr)
            end
        end

        for _, _, ceid in mc_mb:unpack() do
            local dq = w:singleton("pre_depth_queue", "camera_ref:update")
            dq.camera_ref = ceid
            local sdq = w:singleton("scene_depth_queue", "camera_ref:update")
            sdq.camera_ref = ceid
        end
    end
end

local material_cache = {__mode="k"}

function s:end_filter()
    if irender.use_pre_depth() then
        for e in w:select "filter_result:in render_object:in filter_material:in skinning?in" do
            local m = assert(which_material(e.skinning))
            local dst_mi = m.material
            local newstate = irender.check_set_state(dst_mi, e.render_object.material)
            local new_matobj = irender.create_material_from_template(dst_mi:get_material(), newstate, material_cache)
            local fr = e.filter_result
            local qe = w:singleton("pre_depth_queue", "primitive_filter:in")
            local fx = m.fx
            for _, fn in ipairs(qe.primitive_filter) do
                if fr[fn] then
                    e.filter_material[fn] = {
                        material = new_matobj:instance(),
                        fx = fx,
                    }
                end
            end
        end
    end
end


local sd_sys = ecs.system "scene_depth_system"
local function copy_pf(pf)
    local npf = {
        filter_type = ifs.state_names(pf.filter_type)
    }

    for idx, v in ipairs(pf) do
        npf[idx] = v
    end

    return npf
end

function sd_sys.init_world()
    local pd = w:singleton("pre_depth_queue", "render_target:in camera_ref:in primitive_filter:in")
    local pd_rt = pd.render_target
    local pd_vr = pd_rt.view_rect

    ecs.create_entity {
        policy = {
            "ant.render|render_queue",
            "ant.general|name",
        },
        data = {
            camera_ref = pd.camera_ref,
            render_target = {
                view_rect = mu.copy_viewrect(pd_vr),
                viewid = viewidmgr.get "scene_depth",
                fb_idx = fbmgr.create{
                    rbidx = fbmgr.create_rb{
                        format = "D32F", layers = 1,
                        w = pd_vr.w, h = pd_vr.h,
                        flags = sampler{RT="RT_ON",},
                    }
                },
                clear_state = {
                    clear = "D",
                    depth = 1.0,
                },
                view_mode = pd_rt.view_mode,
            },
            primitive_filter = copy_pf(pd.primitive_filter),
            queue_name = "scene_depth_queue",
            name = "scene_depth_queue",
            visible = true,
            scene_depth_queue = true,
        }
    }
end
