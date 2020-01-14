local ecs = ...
local world = ecs.world

local imgui     = require "imgui.ant"
local renderpkg = import_package "ant.render"
local renderutil= renderpkg.util
local fbmgr     = renderpkg.fbmgr
local viewidmgr = renderpkg.viewidmgr

local m = ecs.system "imgui_system"

m.require_interface "ant.timer|timer"

function m:post_init()
    local main_viewid = assert(viewidmgr.get "main_view")
    local vid = imgui.ant.viewid()
    fbmgr.bind(vid, assert(fbmgr.get_fb_idx(main_viewid)))
end

local timer = world:interface "ant.timer|timer"

function m:ui_start()
    local delta = timer.delta()
    imgui.begin_frame(delta * 1000)
end

function m:ui_end()
    imgui.end_frame()
    local vid = imgui.ant.viewid()
    renderutil.update_frame_buffer_view(vid, fbmgr.get_fb_idx(vid))
end
