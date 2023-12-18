local ecs   = ...
local world = ecs.world
local w     = world.w

local setting   = import_package "ant.settings"
local bloom_sys = ecs.system "bloom_system"
local fbmgr     = require "framebuffer_mgr"
if not setting:get "graphic/postprocess/bloom/enable" then
    return
end

local math3d    = require "math3d"
local ips       = ecs.require "ant.render|postprocess.pyramid_sample"
local hwi       = import_package "ant.hwi"

local BLOOM_DS_VIEWID <const> = hwi.viewid_get "bloom_ds1"
local BLOOM_US_VIEWID <const> = hwi.viewid_get "bloom_us1"
local BLOOM_PARAM = math3d.ref(math3d.vector(0, setting:get "graphic/postprocess/bloom/inv_highlight", setting:get "graphic/postprocess/bloom/threshold", 0))


local function register_bloom_queue()
    local bloom_mipcount = ips.get_pyramid_mipcount()
    for i=1, bloom_mipcount do
        local ds_queue  = "bloom_downsample"..i
        local us_queue  = "bloom_upsample"..i
        w:register{name = ds_queue}
        w:register{name = us_queue}
    end
end

local function create_blur_entity()
    world:create_entity{
        policy = {
            "ant.render|pyramid_sample",
            "ant.render|bloom"
        },
        data = {
            bloom = true,
            pyramid_sample = {
                downsample_queue = "bloom_downsample",
                upsample_queue = "bloom_upsample",
                downsample_viewid = BLOOM_DS_VIEWID,
                upsample_viewid = BLOOM_US_VIEWID,
                queue_name = "bloom_queue",
                sample_params = BLOOM_PARAM,
            },
            on_ready = function (e)
                w:extend(e, "pyramid_sample:update")
                local mq = w:first("main_queue render_target:in")
                local mqvr = mq.render_target.view_rect
                ips.set_pyramid_sample_components(e, mqvr)
            end
        }
    }
end

function bloom_sys:init()
    register_bloom_queue()
end

function bloom_sys:init_world()
    create_blur_entity()
end

function bloom_sys:bloom()
    local function update_bloom_handle(ps)
        local last_queue_entity = w:first(("%s%d render_target:in"):format(ps.upsample_queue, ips.get_pyramid_mipcount()))
        if last_queue_entity then
            local fb = fbmgr.get(last_queue_entity.render_target.fb_idx)
            local bloom_color_handle = fbmgr.get_rb(fb[1].rbidx).handle
            local pp = w:first("postprocess postprocess_input:in")
            pp.postprocess_input.bloom_color_handle = bloom_color_handle
        end
    end
    local e = w:first("bloom pyramid_sample:in")
    if e then
        local pp = w:first("postprocess postprocess_input:in")
        local input_handle = pp.postprocess_input.scene_color_handle
        ips.do_pyramid_sample(e, input_handle)
        update_bloom_handle(e.pyramid_sample)
    end
end
