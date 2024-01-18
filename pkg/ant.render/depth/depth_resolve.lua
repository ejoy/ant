local ecs   = ...
local world = ecs.world
local w     = world.w

local hwi       = import_package "ant.hwi"
local sampler   = import_package "ant.render.core".sampler

local fbmgr     = require "framebuffer_mgr"

local bgfx      = require "bgfx"

local icompute = ecs.require "ant.render|compute.compute"
local iviewport = ecs.require "ant.render|viewport.state"

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
    update_resolve_depth(iviewport.viewrect)
end

function depth_resolve_sys:data_changed()
    for _, _, vr in depth_buffer_changed:unpack() do
        update_resolve_depth(vr)
    end
end

local depth_resolve_viewid<const> = hwi.viewid_get "depth_resolve"
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

local depth_mipmap_viewid = hwi.viewid_get "depth_mipmap"
function depth_mipmap_sys:depth_mipmap()
    local vr = iviewport.viewrect
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
