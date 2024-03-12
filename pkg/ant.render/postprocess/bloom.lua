local ecs   = ...
local world = ecs.world
local w     = world.w

local setting   = import_package "ant.settings"
local bloom_sys = ecs.system "bloom_system"
local fbmgr     = require "framebuffer_mgr"
local ifg = ecs.require "ant.render|postprocess.postprocess"
if not setting:get "graphic/postprocess/bloom/enable" then
    return
end

local math3d    = require "math3d"
local ips       = ecs.require "ant.render|postprocess.pyramid_sample"
local hwi       = import_package "ant.hwi"
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
        sample_params   = BLOOM_PARAM,
    }

    pyramid_sampleeid = ips.create(pyramid_sample, iviewport.viewrect)
end

function bloom_sys:init()
    register_queues()
end

function bloom_sys:bloom()
    local function update_bloom_handle(ps)
        local lasteid = ps.upsample[#ps.upsample].queue
        local q = world:entity(lasteid, "render_target:in")
        if q then
            local handle = fbmgr.get_rb(q.render_target.fb_idx, 1).handle
            ifg.set_stage_output("bloom", handle)
        end
    end

    local e = world:entity(pyramid_sampleeid, "pyramid_sample:in")
    local last_output = ifg.get_last_output("bloom")
    ips.do_pyramid_sample(e, last_output)
    update_bloom_handle(e.pyramid_sample)
end
