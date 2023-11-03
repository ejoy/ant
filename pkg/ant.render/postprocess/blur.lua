local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d    = require "math3d"
local renderutil= require "util"
local setting   = import_package "ant.settings"
local blur_sys  = ecs.system "blur_system"
local ips       = ecs.require "ant.render|postprocess.pyramid_sample"

if not setting:get "graphic/postprocess/blur/enable" then
    renderutil.default_system(blur_sys, "init, end_frame")
    return
end

local hwi       = import_package "ant.hwi"

local BLUR_DS_VIEWID <const> = hwi.viewid_get "blur_ds1"
local BLUR_US_VIEWID <const> = hwi.viewid_get "blur_us1"
local BLUR_PARAM = math3d.ref(math3d.vector(0, 0, 0, 0))

local iblur = {}

function blur_sys:init()
    local blur_mipcount = ips.get_pyramid_mipcount()
    for i=1, blur_mipcount do
        local ds_queue  = "blur_downsample"..i
        local us_queue  = "blur_upsample"..i
        w:register{name = ds_queue}
        w:register{name = us_queue}
    end
    world:create_entity{
        policy = {
            "ant.render|pyramid_sample",
            "ant.render|blur"
        },
        data = {
            blur = true,
            pyramid_sample = {
                downsample_queue = "blur_downsample",
                upsample_queue = "blur_upsample",
                downsample_viewid = BLUR_DS_VIEWID,
                upsample_viewid = BLUR_US_VIEWID,
                queue_name = "blur_queue",
                sample_params = BLUR_PARAM,
            },
        }
    }
end

function blur_sys:end_frame()
    for be in w:select "blur pyramid_sample:in blur pyramid_sample_ready:update" do
        ips.set_pyramid_visible(be, false)
        be.pyramid_sample_ready = false
    end
end 

return iblur