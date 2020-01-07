local ecs = ...
local imgui     = require "imgui.ant"
local renderpkg = import_package "ant.render"
local timer     = import_package "ant.timer"
local renderutil= renderpkg.util
local fbmgr     = renderpkg.fbmgr
local viewidmgr = renderpkg.viewidmgr

local m = ecs.system "imgui_system"

function m:post_init()
    local main_viewid = assert(viewidmgr.get "main_view")
    local vid = imgui.ant.viewid()
    fbmgr.bind(vid, assert(fbmgr.get_fb_idx(main_viewid)))
end

function m:ui_start()
    local time = timer.deltatime/1000
    if time <= 0.0 then
        time = 1.0/60
    end

    imgui.begin_frame(time)
end

function m:ui_end()
    imgui.end_frame()
    local vid = imgui.ant.viewid()
    renderutil.update_frame_buffer_view(vid, fbmgr.get_fb_idx(vid))
end
