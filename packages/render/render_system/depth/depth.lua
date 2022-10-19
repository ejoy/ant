local ecs   = ...
local world = ecs.world
local w     = world.w
local mu = import_package "ant.math".util

local fbmgr     = require "framebuffer_mgr"
local viewidmgr = require "viewid_mgr"
local sampler   = require "sampler"

local irender   = ecs.import.interface "ant.render|irender"
local irq       = ecs.import.interface "ant.render|irenderqueue"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local ivs       = ecs.import.interface "ant.scene|ivisible_state"
local bgfx      = require "bgfx"


local sd_sys = ecs.system "scene_depth_system"

function sd_sys.post_init()
    local vr = world.args.viewport
    ecs.create_entity {
        policy = {
            "ant.render|scene_depth_queue",
            "ant.general|name",
        },
        data = {
            camera_ref = 0,
            render_target = {
                view_rect = mu.copy_viewrect(vr),
                viewid = viewidmgr.get "scene_depth",
                fb_idx = fbmgr.create{
                    rbidx = fbmgr.create_rb{
                        format = "D16F", layers = 1,
                        w = vr.w, h = vr.h,
                        flags = sampler{RT="RT_ON",},
                    }
                },
                clear_state = {
                    clear = "D",
                    depth = 0.0,
                },
                view_mode = "s",
            },
            primitive_filter = {
                filter_type = "main_view",
                "opacity",
            },
            queue_name = "scene_depth_queue",
            name = "scene_depth_queue",
            visible = false,
            scene_depth_queue = true,
            on_ready = function (e)
                local pd = w:first("pre_depth_queue camera_ref:in")
                irq.set_camera("scene_depth_queue", pd.camera_ref)
            end
        }
    }
end


local pre_depth_material
local pre_depth_skinning_material

local function which_material(skinning)
	local res = skinning and pre_depth_skinning_material or pre_depth_material
    return res.object
end


local s = ecs.system "pre_depth_system"

function s:init()
    if not irender.use_pre_depth() then
        return
    end

    pre_depth_material 			= imaterial.load_res "/pkg/ant.resources/materials/predepth.material"
    pre_depth_skinning_material = imaterial.load_res "/pkg/ant.resources/materials/predepth_skin.material"
end

local vr_mb = world:sub{"view_rect_changed", "main_queue"}
local mc_mb = world:sub{"main_queue", "camera_changed"}
function s:data_changed()
    if irender.use_pre_depth() then
        for msg in vr_mb:each() do
            local vr = msg[3]
            local dq = w:first("pre_depth_queue render_target:in")
            local dqvr = dq.render_target.view_rect
            --have been changed in viewport detect
            assert(vr.w == dqvr.w and vr.h == dqvr.h)
            if vr.x ~= dqvr.x or vr.y ~= dqvr.y then
                irq.set_view_rect("pre_depth_queue", vr)
                irq.set_view_rect("scene_depth_queue", vr)
            end
        end

        for _, _, ceid in mc_mb:unpack() do
            local e = w:first("pre_depth_queue", "camera_ref:out")
            e.camera_ref = ceid
            w:submit(e)

            e = w:first("scene_depth_queue", "camera_ref:out")
            e.camera_ref = ceid
            w:submit(e)
        end
    end
end

local material_cache = {__mode="k"}

function s:end_filter()
    if irender.use_pre_depth() then
        for e in w:select "filter_result pre_depth_queue_visible opacity render_object:update filter_material:in skinning?in scene_depth_queue_visible?out" do
            local mo = assert(which_material(e.skinning))
            local ro = e.render_object
            local fm = e.filter_material
            
            local newstate = irender.check_set_state(mo, fm.main_queue:get_material())
            local new_mo = irender.create_material_from_template(mo, newstate, material_cache)

            local mi = new_mo:instance()

            local h = mi:ptr()
            fm["pre_depth_queue"] = mi
            ro.mat_predepth = h

            fm["scene_depth_queue"] = mi
            ro.mat_scenedepth = h

            e["scene_depth_queue_visible"] = true
        end
    end
end

local icompute = ecs.import.interface "ant.render|icompute"

--resolve depth
local depth_resolve_sys = ecs.system "depth_resolve_system"

local dispatch_size_x<const>, dispatch_size_y<const> = 16, 16
function depth_resolve_sys:init()
    icompute.create_compute_entity(
        "depth_resolve",
        "/pkg/ant.resources/materials/depth/depth_resolve.material",
        {1, 1, 1})
end

local depth_buffer_changed = world:sub{"view_rect_changed", "pre_depth_queue"}

local function update_dispatch_size(ww, hh, d)
    d[1] = (ww + dispatch_size_x) // dispatch_size_x
    d[2] = (hh + dispatch_size_y) // dispatch_size_y
end

local require_depth_mipmap = false

local function create_resolve_depth(vr)
    return bgfx.create_texture2d(vr.w, vr.h, require_depth_mipmap, 1, "D16F", sampler{
        MIN="POINT",
        MAG="POINT",
        U="CLAMP",
        V="CLAMP",
        RT="RT_ON",
    })
end

local function update_resolve_depth(vr)
    local rde = w:first "depth_resolve dispatch:in"
    local dis = rde.dispatch
    update_dispatch_size(vr.w, vr.h, dis.size)

    if dis.resolve_depth_handle then
        bgfx.destroy(dis.resolve_depth_handle)
    end

    dis.resolve_depth_handle = create_resolve_depth(vr)
end

function depth_resolve_sys:init_world()
    update_resolve_depth(world.args.viewport)
end

function depth_resolve_sys:data_changed()
    for _, _, vr in depth_buffer_changed:unpack() do
        update_resolve_depth(vr)
    end
end

local depth_resolve_viewid = viewidmgr.get "depth_resolve"
function depth_resolve_sys:depth_resolve()
    local e = w:first "depth_resolve dispatch:in"
    local m = e.dispatch.material
    local pdq = w:first "pre_depth_queue render_target:in"
    local fbidx = pdq.render_target.fb_idx
    m.s_depthMSAA = fbmgr.get(fbidx)[1].handle
    m.s_depth = icompute.create_image_property(e.dispatch.resolve_depth_handle, 1, 0, "w")
    icompute.dispatch(depth_resolve_viewid, e.dispatch)
end

--depth mipmap
local depth_mipmap_sys = ecs.system "depth_mipmap_system"
function depth_mipmap_sys:init()
    require_depth_mipmap = true
    icompute.create_compute_entity(
        "depth_mipmap",
        "/pkg/ant.resources/materials/depth/depth_mipmap.material",
        {1, 1, 1})
end

local depth_mipmap_viewid = viewidmgr.get "depth_mipmap"
function depth_mipmap_sys:depth_mipmap()
    local vr = world.args.viewport
    local nummip = math.log(math.max(vr.w, vr.h), 2)+1

    local e = w:first "depth_mipmap dispatch:in"
    local dis = e.dispatch
    local m = dis.material

    local rde = w:first "depth_resolve dispatch:in"
    local depthhandle = rde.dispatch.resolve_depth_handle

    local ip = icompute.create_image_property(depthhandle, 0, 0,"r")

    local ww, hh = vr.w, vr.h
    for mip=1, nummip-1 do
        local nw, nh = ww//2, hh//2
        update_dispatch_size(nw, nh, dis.size)
        ip.mip, ip.access = mip-1, "r"
        m.s_depth       = ip
        ip.mip, ip.access = mip, "w"
        m.s_depth_next  = ip
        icompute.dispatch(depth_mipmap_viewid, dis)

        ww, hh = nw, nh
    end
end
