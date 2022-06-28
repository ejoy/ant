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
local iRmlUi = ecs.interface "irmlui"

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
    iRmlUi.font_dir "/pkg/ant.resources.binary/ui/test/assets/font/"

    local vp = world.args.viewport
    ecs.create_entity{
        policy = {
            "ant.general|name",
            "ant.render|render_target",
            "ant.render|watch_screen_buffer",
        },
        data = {
            rmlui_obj = true,
            render_target = {
                view_rect = {x=vp.x, y=vp.y, w=vp.w, h=vp.h},
                viewid = ui_viewid,
                view_mode = "s",
                clear_state = {
                    clear = "",
                },
            },
            watch_screen_buffer = true,
            name = "rmlui_obj",
        }
    }
end

local vp_changed_mb = world:sub{"world_viewport_changed"}

function rmlui_sys:entity_init()
    for q in w:select "INIT rmlui_obj render_target:in" do
        local rt = q.render_target
        local vr = rt.view_rect
        ltask.send(ServiceRmlUi, "update_context_size", vr.w, vr.h, world.args.framebuffer.ratio)
    end

    for _, vr in vp_changed_mb:unpack() do
        irq.set_view_rect("rmlui_obj", vr)
        ltask.send(ServiceRmlUi, "update_context_size", vr.w, vr.h, world.args.framebuffer.ratio)
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

function iRmlUi.font_dir(dir)
    ltask.call(ServiceRmlUi, "font_dir", dir)
end

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
