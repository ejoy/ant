local ecs = ...
local imgui = require "imgui"
local imgui_ant = require "imgui.ant"
local renderpkg = import_package "ant.render"
local timer = import_package "ant.timer"
local renderutil= renderpkg.util
local fbmgr = renderpkg.fbmgr

local m = ecs.system "imgui_start_system"
m.step "ui_start"
function m:update()
    local time = timer.deltatime/1000
    if time <= 0.0 then
        time = 1.0/60
    end
    imgui.begin_frame(time)
end

local m = ecs.system "imgui_end_system"
m.step "ui_end"
function m:update()
    imgui.end_frame()
    local vid = imgui_ant.viewid()
    renderutil.update_frame_buffer_view(vid, fbmgr.get_fb_idx(vid))
end
