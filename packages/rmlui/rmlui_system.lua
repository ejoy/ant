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

local thread     = require "thread"
thread.newchannel "rmlui"
local channel    = thread.channel_produce "rmlui"

local rmlui_sys = ecs.system "rmlui_system"

local function init_rmlui_data()
    local ft_w, ft_h = ifont.font_tex_dim()

    local mq_eid = world:singleton_entity_id "main_queue"
    local  layouhandle = declmgr.get "p2|c40niu|t20".handle
    local vid = viewidmgr.get "uiruntime"
    local vr = irq.view_rect(mq_eid)
    fbmgr.bind(vid, irq.frame_buffer(mq_eid))

    local default_texid = assetmgr.resource "/pkg/ant.resources/textures/default/1x1_white.texture".handle
    return {
		viewid = vid,
        shader = {
            font_mask = 0.6,
            font_range = 0.05,
            font = assetmgr.load_fx {
                fs = "/pkg/ant.resources/shaders/font/fs_uifont.sc",
                vs = "/pkg/ant.resources/shaders/font/vs_uifont.sc",
            },
            font_outline = assetmgr.load_fx {
                fs = "/pkg/ant.resources/shaders/font/fs_uifont.sc",
                vs = "/pkg/ant.resources/shaders/font/vs_uifont.sc",
                setting = {macros = {"OUTLINE_EFFECT"}},
            },
            font_shadow = assetmgr.load_fx {
                fs = "/pkg/ant.resources/shaders/font/fs_uifont.sc",
                vs = "/pkg/ant.resources/shaders/font/vs_uifont.sc",
                setting = {macros = {"SHADOW_EFFECT"}},
            },
            font_glow = assetmgr.load_fx {
                fs = "/pkg/ant.resources/shaders/font/fs_uifont.sc",
                vs = "/pkg/ant.resources/shaders/font/vs_uifont.sc",
                setting = {macros = {"GLOW_EFFECT"}},
            },
            image = assetmgr.load_fx {
                fs = "/pkg/ant.resources/shaders/ui/fs_image.sc",
                vs = "/pkg/ant.resources/shaders/ui/vs_image.sc",
            },
        },
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
    }
end

local function preload_dir(dir)
    dir = fs.path(dir)
    local file_dict = {}
    local function list_files(path)
        for p in path:list_directory() do
            if fs.is_directory(p) then
                list_files(p)
            elseif fs.is_regular_file(p) then
                if p:equal_extension "otf" or p:equal_extension "ttf" or p:equal_extension "ttc" then
                    fontmgr.import(p)
                end
                local key = fs.relative(p, dir):string()
                file_dict[key] = p:localpath():string()
            end
        end
    end
    list_files(dir)
    rmlui.preload_file(file_dict)
end

function rmlui_sys:init()
	local data = init_rmlui_data()
	local thread = require "common.thread"
    rmlui.init(data, thread.bootstrap("rmlui", [[
		require "bootstrap"
		return import_package "ant.rmlui"
	]]))
    preload_dir "/pkg/ant.resources.binary/ui/test"
end

local eventMouse = world:sub {"mouse"}
local mouseId = { LEFT = 0, RIGHT = 1, MIDDLE = 2}
function rmlui_sys:ui_update()
    for _,what,state,x,y in eventMouse:unpack() do
        if state == "MOVE" then
            channel("MouseMove", x, y)
        elseif state == "DOWN" then
            channel("MouseDown", mouseId[what])
        elseif state == "UP" then
            channel("MouseUp", mouseId[what])
        end
    end
    rmlui.update()
end

function rmlui_sys:exit()
    rmlui.shutdown()
end


local iRmlUi = ecs.interface "rmlui"

function iRmlUi.preload_dir(dir)
    preload_dir(dir)
end

function iRmlUi.message(...)
    channel(...)
end
