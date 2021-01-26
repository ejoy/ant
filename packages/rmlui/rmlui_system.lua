local ecs = ...
local world = ecs.world

local assetmgr = import_package "ant.asset"

local fs        = require "filesystem"
local rmlui     = require "rmlui"
local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local declmgr   = renderpkg.declmgr
local fbmgr     = renderpkg.fbmgr

local fontpkg   = import_package "ant.font"
local fontmgr   = fontpkg.mgr

local ifont     = world:interface "ant.render|ifont"
local irq       = world:interface "ant.render|irenderqueue"
local timer     = world:interface "ant.timer|timer"

local thread     = require "thread"
thread.newchannel "rmlui_req"
thread.newchannel "rmlui_res"
local req = thread.channel_produce "rmlui_req"
local res = thread.channel_consume "rmlui_res"

local rmlui_sys = ecs.system "rmlui_system"

local function preload_dir(dir)
    local function import_font(path)
        for p in path:list_directory() do
            if fs.is_directory(p) then
                import_font(p)
            elseif fs.is_regular_file(p) then
                if p:equal_extension "otf" or p:equal_extension "ttf" or p:equal_extension "ttc" then
                    fontmgr.import(p)
                end
            end
        end
    end
    import_font(fs.path(dir))
    req("add_resource_dir", dir)
end

function rmlui_sys:init()
    local ft_w, ft_h = ifont.font_tex_dim()

    local mq_eid = world:singleton_entity_id "main_queue"
    local layouhandle = declmgr.get "p2|c40niu|t20".handle
    local vid = viewidmgr.get "uiruntime"
    local vr = irq.view_rect(mq_eid)
    fbmgr.bind(vid, irq.frame_buffer(mq_eid))

    local default_texid = assetmgr.resource "/pkg/ant.resources/textures/default/1x1_white.texture".handle

    local function create_font_shader(effectname)
        local setting = {}
        if effectname then
            setting[effectname] = 1
        end
        return {
            fs = "/pkg/ant.resources/shaders/font/fs_uifont.sc",
            vs = "/pkg/ant.resources/shaders/font/vs_uifont.sc",
            setting = setting,
        }
    end

    local shader_defines = {
        image = {
            fs = "/pkg/ant.resources/shaders/ui/fs_image.sc",
            vs = "/pkg/ant.resources/shaders/ui/vs_image.sc",
            setting = {}
        },
        font = create_font_shader(),
        font_outline = create_font_shader "OUTLINE_EFFECT",
        font_shadow = create_font_shader "SHADOW_EFFECT",
    }

    local function create_shaders(def)
        local shaders = {}
        for k, v in pairs(def) do
            shaders[k] = assetmgr.load_fx(v)
            v.setting["ENABLE_CLIP_RECT"] = 1
            shaders[k .. "_cr"] = assetmgr.load_fx(v)
        end
        return shaders
    end
    local shaders = create_shaders(shader_defines)
    shaders.debug_draw = assetmgr.load_fx{
        vs = "/pkg/ant.resources/shaders/ui/vs_debug.sc",
        fs = "/pkg/ant.resources/shaders/ui/fs_debug.sc",
    }

    rmlui.init {
		viewid = vid,
        shader = shaders,
        font_mgr = ifont.handle(),
        default_tex = {
            width = 1, height = 1,
            texid = default_texid,
        },
        font_tex = {
            texid = ifont.font_tex_handle(),
            width = ft_w, height = ft_h,
        },
        viewrect= vr,
        layout  = layouhandle,
        bootstrap = require "common.thread".bootstrap("rmlui", [[
            require "bootstrap"
            return import_package "ant.rmlui"
        ]])
    }
    preload_dir "/pkg/ant.resources.binary/ui/test/assets/font/"
end

local windows = {}
local events = {}
local CMD = {}

function CMD.message(name, data)
    local window = windows[name]
    local event = events[name]
    if window and event and event.message then
        event.message {
            source = window,
            data = data,
        }
    end
end

local function message(ok, what, ...)
    if not ok then
        return false
    end
    if CMD[what] then
        CMD[what](...)
    end
    return true
end

local eventMouse = world:sub {"mouse"}
local mouseId = { LEFT = 0, RIGHT = 1, MIDDLE = 2}
function rmlui_sys:ui_update()
    for _,what,state,x,y in eventMouse:unpack() do
        if state == "MOVE" then
            req("mouseMove", x, y)
        elseif state == "DOWN" then
            req("mouseDown", mouseId[what])
        elseif state == "UP" then
            req("mouseUp", mouseId[what])
        end
    end
    rmlui.update(timer.delta())
    while message(res:pop()) do
    end
end

function rmlui_sys:exit()
    rmlui.shutdown()
end


local iRmlUi = ecs.interface "rmlui"
local maxID = 0

function iRmlUi.preload_dir(dir)
    preload_dir(dir)
end

function iRmlUi.initialize(w, h)
    req("initialize", w, h)
end

function iRmlUi.update_viewrect(x, y, w, h)
    req("update_viewrect", x, y, w, h)
    --rmlui.update_viewrect(x, y, w, h)
end

function iRmlUi.debugger(open)
    req("debugger", open)
end

function iRmlUi.open(url)
    maxID = maxID + 1
    local name = "#"..maxID
    req("open", name, url)
    local w = {}
    local event = {}
    windows[name] = w
    events[name] = event
    function w.close()
        req("close", name)
        windows[name] = nil
        events[name] = nil
    end
    function w.postMessage(data)
        req("postMessage", name, data)
    end
    function w.addEventListener(type, listener)
        event[type] = listener
    end
    return w
end
