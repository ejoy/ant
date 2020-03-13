local ecs = ...
local world = ecs.world

local viewidmgr = require "viewid_mgr"
local fbmgr = require "framebuffer_mgr"
local fs = require "filesystem"

local cu = require "camera.util"

local setting = require "setting"

local tm = ecs.system "tonemapping"
tm.require_singleton "postprocess"
tm.require_system    "postprocess_system"
tm.require_interface "postprocess"

local ipp = world:interface "postprocess"

function tm:post_init()
    local sd = setting.get()
    local hdrsetting = sd.graphic.hdr
    local pp = world:singleton "postprocess"
    if hdrsetting.enable then
        local main_fbidx = fbmgr.get_fb_idx(viewidmgr.get "main_view")

        local fbsize = ipp.main_rb_size(main_fbidx)
        cu.main_queue_camera()
        local techniques = pp.techniques
        techniques[#techniques+1]
            {
                name = "tonemapping",
                passes = {
                    {
                        name = "main",
                        material = {
                            {
                                ref_path = fs.path "/pkg/ant.resources/depiction/materials/postprocess/tonemapping.material",
                            }
                        },
                        output = {
                            fb_idx = main_fbidx,
                            rb_idx = 1,
                        },
                        viewport = {
                            rect = {x=0, y=0, w=fbsize.w, h=fbsize.h},
                            clear_state = {clear=""},
                        }
                    },
                }
            }
    end
end