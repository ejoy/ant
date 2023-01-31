local ecs = ...
local world = ecs.world
local w = world.w

local ltask     = require "ltask"
local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local fbmgr     = renderpkg.fbmgr
local sampler   = renderpkg.sampler
local font      = import_package "ant.font"
local ServiceRmlUi = ltask.queryservice "ant.rmlui|rmlui"
local irq       = ecs.import.interface "ant.render|irenderqueue"
local rmlui_sys = ecs.system "rmlui_system"
local iRmlUi = ecs.interface "irmlui"
local fs = require "filesystem"
local iUiRt = ecs.interface "iuirt"
local ui_viewid<const> = viewidmgr.get "uiruntime"

function rmlui_sys:init()
    local ft_handle, ft_w, ft_h = font.texture()

    ltask.call(ServiceRmlUi, "initialize", {
        service_world = ltask.self(),
        viewid = ui_viewid,
        font_mgr = font.handle(),
        font_tex = {
            texid = ft_handle,
            width = ft_w, height = ft_h,
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
        local rml = w:first("rmlui_obj render_target:in")
        if rml then
            irq.set_view_rect("rmlui_obj", vr)
            ltask.send(ServiceRmlUi, "update_context_size", vr.w, vr.h, world.args.framebuffer.ratio)
        end
    end
end


local S = ltask.dispatch()

local msgqueue = {}

function S.rmlui_message(...)
	msgqueue[#msgqueue+1] = {...}
end

local rb_flags = sampler{
    MIN="POINT",
    MAG="POINT",
    U="CLAMP",
    V="CLAMP",
    RT="RT_ON",
}

local lastname = "pickup_blit"

function S.render_target_create(width, height, name)
    local viewid = viewidmgr.generate(name, lastname)
    local rbidx = fbmgr.create_rb{w = width, h = height, layers = 1, format = "RGBA32F", flags = rb_flags}
    local fbidx = fbmgr.create{
        rbidx = rbidx
    }
    local id = fbmgr.get_rb(fbidx, 1).handle
    local queuename = name .. "_queue"
    local mq = w:first "main_queue camera_ref:in"
    ecs.create_entity {
		policy = {
			"ant.render|render_queue",
			"ant.render|watch_screen_buffer",
			"ant.general|name",
		},
		data = {
            camera_ref = mq.camera_ref,
			render_target = {
				viewid		= viewid,
				view_mode 	= "s",
                clear_state = {
                    color = 0x000000ff,
                    depth = 0.0,
                    clear = "CD",
                },
				view_rect	= {x = 0, y = 0, w = width, h = height},
				fb_idx		= fbidx,
			},
            [queuename]         = true,
			name 				= queuename,
			queue_name			= queuename,
            visible = true,
			watch_screen_buffer	= true,
		}
	}
    lastname = name
    iUiRt.gen_group_id(name)
    return id
end

local windows = {}
local events = {}

function rmlui_sys:ui_update()
    if #msgqueue == 0 then
        return
    end
    local mq = msgqueue
    msgqueue = {}
    for i = 1, #mq do
        local msg = mq[i]
        local name, data = msg[1], msg[2]
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

local function import_font(path)
    for p in fs.pairs(path) do
        if fs.is_directory(p) then
            import_font(p)
        elseif fs.is_regular_file(p) then
            if p:equal_extension "otf" or p:equal_extension "ttf" or p:equal_extension "ttc" then
                font.import(p)
            end
        end
    end
end

function iRmlUi.font_dir(dir)
    import_font(fs.path(dir))
end

function iRmlUi.add_bundle(dir)
    ltask.call(ServiceRmlUi, "add_bundle", dir)
end

function iRmlUi.del_bundle(dir)
    ltask.call(ServiceRmlUi, "del_bundle", dir)
end

function iRmlUi.set_prefix(dir)
    ltask.call(ServiceRmlUi, "set_prefix", dir)
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
