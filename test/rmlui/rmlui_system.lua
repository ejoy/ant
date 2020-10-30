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

local rmlui_sys = ecs.system "rmlui_system"

local script_dir = fs.path "/pkg/ant.test.rmlui/ui"
local resource_dir = fs.path "/pkg/ant.resources.binary/ui/test"

local function init_rmlui_data()
    local ft_w, ft_h = ifont.font_tex_dim()

    local function list_all_files(root, files)
        local function list_files(path)
            for p in path:list_directory() do
                if fs.is_directory(p) then
                    list_files(p)
                elseif fs.is_regular_file(p) then
                    local key = p:string():gsub(root:string() .. "/", "")
                    files[key] = p:localpath():string()
                end
            end
        end
        list_files(root)
    end

    local file_dict = {}
    list_all_files(resource_dir, file_dict)
    list_all_files(script_dir, file_dict)

    local mq_eid = world:singleton_entity_id "main_queue"
    local  layouhandle = declmgr.get "p2|c40niu|t20".handle
    local vid = viewidmgr.get "uiruntime"
    local vr = irq.view_rect(mq_eid)
    fbmgr.bind(vid, irq.frame_buffer(mq_eid))

    local default_texid = assetmgr.resource "/pkg/ant.resources/textures/default/1x1_white.texture".handle
    return {
        file_dict = file_dict,
        viewid = vid,
        shader = {
            font_mask = 0.68,
            font_range = 0.18,
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
                setting = {macros = {"OUTLINE_SHADOW"}},
            },
            font_glow = assetmgr.load_fx {
                fs = "/pkg/ant.resources/shaders/font/fs_uifont.sc",
                vs = "/pkg/ant.resources/shaders/font/vs_uifont.sc",
                setting = {macros = {"OUTLINE_GLOW"}},
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

local rmlui_context
function rmlui_sys:post_init()
    local data = init_rmlui_data()
    rmlui_context = rmlui.init(data)
    for f in pairs(data.file_dict) do
        local ext = f:match ".+%.([%w_]+)$":lower()
        if ext == "otf" or ext == "ttf" or ext == "ttc" then
            fontmgr.import(resource_dir / f)
        end
    end

    local vr = irq.view_rect(world:singleton_entity_id "main_queue")
    rmlui_context:create("main", vr.w, vr.h)
    rmlui_context:load "tutorial.rml"
end

local eventMouse = world:sub {"mouse"}
local eventKeyboard = world:sub {"keyboard", "F8"}
local mouseId = { LEFT = 0, RIGHT = 1, MIDDLE = 2}
function rmlui_sys:ui_update()
    for _,what,state,x,y in eventMouse:unpack() do
        if state == "MOVE" then
            rmlui_context:touch_move(x, y)
        elseif state == "DOWN" then
                rmlui_context:touch_down(mouseId[what])
            elseif state == "UP" then
                rmlui_context:touch_up(mouseId[what])
            else
        end
    end
	for _,_,press in eventKeyboard:unpack() do
		if press == 1 then
			rmlui_context:debugger()
		end
	end
    rmlui_context:render()
end

function rmlui_sys:exit()
    rmlui_context:shutdown()
end