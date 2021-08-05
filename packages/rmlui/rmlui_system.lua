local ecs = ...
local world = ecs.world
local w = world.w
local assetmgr = import_package "ant.asset"

local ltask     = require "ltask"
local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local fbmgr     = renderpkg.fbmgr

local font      = import_package "ant.font"
local irq       = world:interface "ant.render|irenderqueue"
local icamera   = world:interface "ant.camera|camera"
local ServiceRmlUi = ltask.spawn "rmlui"

local rmlui_sys = ecs.system "rmlui_system"
local iRmlUi = ecs.interface "rmlui"

function rmlui_sys:init()
    local default_texid = assetmgr.resource "/pkg/ant.resources/textures/default/1x1_white.texture".handle
    local ft_handle, ft_w, ft_h = font.texture()
    
    ltask.call(ServiceRmlUi, "initialize", {
        service_world = ltask.self(),
        viewid = viewidmgr.get "uiruntime",
        font_mgr = font.handle(),
        font_tex = {
            texid = ft_handle,
            width = ft_w, height = ft_h,
        },
        viewrect = {x=0, y=0, w=1, h=1},
        default_tex = {
            width = 1, height = 1,
            texid = default_texid,
        },
    })
    iRmlUi.preload_dir "/pkg/ant.resources.binary/ui/test/assets/font/"
end

function rmlui_sys:entity_init()
    for qe in w:select "INIT main_queue render_target:in" do
        local vid = viewidmgr.get "uiruntime"
        local rt = qe.render_target
        fbmgr.bind(vid, rt.fb_idx)
        local vr = rt.view_rect
        ltask.send(ServiceRmlUi, "update_viewrect", vr.x, vr.y, vr.w, vr.h)
    end
end

local windows = {}
local events = {}

local eventTaskMessage = world:sub {"task-message","rmlui"}
function rmlui_sys:ui_update()
    for _, _, name, data in eventTaskMessage:unpack() do
        local window = windows[name]
        local event = events[name]
        if window and event and event.message then
            event.message {
                source = window,
                data = data,
            }
        end
    end
end

function rmlui_sys:exit()
    ltask.call(ServiceRmlUi, "shutdown")
end

local maxID = 0

function iRmlUi.preload_dir(dir)
    ltask.call(ServiceRmlUi, "preload_dir", dir)
end

function iRmlUi.update_viewrect(x, y, w, h)
    for qe in world.w:select "main_queue render_target:in" do
        local vid = viewidmgr.get "uiruntime"
        local rt = qe.render_target
        if qe.camera_eid then
            icamera.set_frustum_aspect(qe.camera_eid, w/h)
        end
        fbmgr.bind(vid, rt.fb_idx)
    end
    ltask.send(ServiceRmlUi, "update_viewrect", x, y, w, h)
end

function iRmlUi.debugger(open)
    ltask.send(ServiceRmlUi, "debugger", open)
end

function iRmlUi.open(url)
    maxID = maxID + 1
    local name = "#"..maxID
    ltask.send(ServiceRmlUi, "open", name, url)
    local w = {}
    local event = {}
    windows[name] = w
    events[name] = event
    function w.close()
        ltask.send(ServiceRmlUi, "close", name)
        windows[name] = nil
        events[name] = nil
    end
    function w.postMessage(data)
        ltask.send(ServiceRmlUi, "postMessage", name, data)
    end
    function w.addEventListener(type, listener)
        event[type] = listener
    end
    return w
end
