local ecs = ...
local world = ecs.world
local w = world.w
local assetmgr = import_package "ant.asset"

local ltask     = require "ltask"
local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr

local font      = import_package "ant.font"
local ServiceRmlUi = ltask.spawn "ant.rmlui|rmlui"
local irq       = ecs.import.interface "ant.render|irenderqueue"
local rmlui_sys = ecs.system "rmlui_system"
local iRmlUi = ecs.interface "rmlui"

local ui_viewid<const> = viewidmgr.get "uiruntime"

function rmlui_sys:init()
    local default_texid = assetmgr.resource "/pkg/ant.resources/textures/default/1x1_white.texture".handle
    local ft_handle, ft_w, ft_h = font.texture()

    ltask.call(ServiceRmlUi, "initialize", {
        service_world = ltask.self(),
        viewid = ui_viewid,
        font_mgr = font.handle(),
        font_tex = {
            texid = ft_handle,
            width = ft_w, height = ft_h,
        },
        default_tex = {
            width = 1, height = 1,
            texid = default_texid,
        },
    })
    iRmlUi.preload_dir "/pkg/ant.resources.binary/ui/test/assets/font/"
end

function rmlui_sys:init_world()
    local mq = w:singleton("main_queue", "render_target:in")
    local rt = mq.render_target
    local vr = rt.view_rect
    ecs.create_entity{
        policy = {
            "ant.general|name",
            "ant.render|render_target",
            "ant.render|watch_screen_buffer",
        },
        data = {
            rmlui_obj = true,
            render_target = {
                view_rect = {x=vr.x, y=vr.y, w=vr.w, h=vr.h},
                viewid = ui_viewid,
                view_mode = "s",
                clear_state = {
                    clear = "",
                },
                fb_idx = rt.fb_idx,
            },
            watch_screen_buffer = true,
            name = "rmlui_obj",
        }
    }
end

local vr_change_mb = world:sub{"component_changed", "view_rect", "main_queue"}

function rmlui_sys:entity_init()
    for q in w:select "INIT rmlui_obj render_target:in" do
        local vr = q.render_target.view_rect
        ltask.send(ServiceRmlUi, "update_context_size", vr.w, vr.h)
    end

    for q in w:select "rmlui_obj render_target_changed render_target:in" do
        local vr = q.render_target.view_rect
        ltask.send(ServiceRmlUi, "update_context_size", vr.w, vr.h)
    end

    for _ in vr_change_mb:each() do
        irq.set_view_rect("rmlui_obj", irq.view_rect"main_queue")
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
    ltask.send(ServiceRmlUi, "shutdown")
end

local maxID = 0

function iRmlUi.preload_dir(dir)
    ltask.call(ServiceRmlUi, "preload_dir", dir)
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
