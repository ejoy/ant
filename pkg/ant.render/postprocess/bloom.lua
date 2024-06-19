local ecs   = ...
local world = ecs.world
local w     = world.w

local setting   = import_package "ant.settings"
if not setting:get "graphic/postprocess/bloom/enable" then
    return
end
local fbmgr     = require "framebuffer_mgr"
local math3d    = require "math3d"

local hwi       = import_package "ant.hwi"

local fg        = ecs.require "ant.render|framegraph"
local ips       = ecs.require "ant.render|postprocess.pyramid_sample"

local iviewport = ecs.require "viewport.state"
local queuemgr  = ecs.require "queue_mgr"

local DOWNSAMPLE_NAME<const> = "bloom_downsample"
local UPSAMPLE_NAME<const> = "bloom_upsample"

local BLOOM_DS_VIEWID <const> = hwi.viewid_get "bloom_ds1"
local BLOOM_US_VIEWID <const> = hwi.viewid_get "bloom_us1"
local BLOOM_PARAM = math3d.ref(math3d.vector(0, setting:get "graphic/postprocess/bloom/inv_highlight", setting:get "graphic/postprocess/bloom/threshold", 0))

local MIP_COUNT<const> = 4

local pyramid_sampleeid
local function register_queues()
    for i=1, MIP_COUNT do
        queuemgr.register_queue(DOWNSAMPLE_NAME..i)
        queuemgr.register_queue(UPSAMPLE_NAME..i)
    end

    local pyramid_sample = {
        downsample      = ips.init_sample(MIP_COUNT, DOWNSAMPLE_NAME,   BLOOM_DS_VIEWID),
        upsample        = ips.init_sample(MIP_COUNT, UPSAMPLE_NAME,     BLOOM_US_VIEWID),
    }

    pyramid_sampleeid = ips.create(pyramid_sample, iviewport.viewrect)
end

local bloom_sys = ecs.system "bloom_system"

local SCENE_COLOR_PROPERTY = {
    stage   = 0,
    mip     = 0,
    access  = "r",
    type    = 'i',
    value   = nil,
}

local param_modifier = {
    update = function (s, mi, mip)
        SCENE_COLOR_PROPERTY.mip    = mip
        SCENE_COLOR_PROPERTY.handle = s.handle
        mi.s_scene_color            = SCENE_COLOR_PROPERTY
        mi.u_bloom_param            = BLOOM_PARAM
    end
}

function bloom_sys:init()
    register_queues()
    fg.register_pass("bloom", {
        depends = {"main_view"},
        init = function ()
            local main_viewid = hwi.viewid_get "main_view"
            local fb = fbmgr.get_byviewid(main_viewid)
            ips.update_smaple_handles(world:entity(pyramid_sampleeid, "pyramid_sample:in"), fbmgr.get_rb(fb, 1).handle)
        end,
        run = function (self)
            local e = world:entity(pyramid_sampleeid, "pyramid_sample:in")
            ips.do_pyramid_sample(e, param_modifier)
        end,
    })
end

local vr_mb = world:sub{"view_rect_changed", "main_queue"}
function bloom_sys:data_changed()
    for msg in vr_mb:each() do
        local vr = msg[3]
        local e = world:entity(pyramid_sampleeid, "pyramid_sample:in")
        ips.update_viewrect(e, vr)
        break
    end

end
