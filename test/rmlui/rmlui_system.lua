local ecs = ...
local world = ecs.world

local assetmgr = import_package "ant.asset"

local fs        = require "filesystem"
local rmlui     = require "rmlui"
local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local declmgr   = renderpkg.declmgr
local fbmgr     = renderpkg.fbmgr

local ifont     = world:interface "ant.render|ifont"
local irq       = world:interface "ant.render|irenderqueue"

local rmlui_sys = ecs.system "rmlui_system"

local root_dir = fs.path "/pkg/ant.resources.binary/ui"

local function init_rmlui_data()
    local ft_w, ft_h = ifont.font_tex_dim()
    local fontinfo = {
        font_mgr = ifont.handle(),
        font_texture = {
            texid = ifont.font_tex_handle(),
            width = ft_w, height = ft_h,
        },
    }

    local files = {}
    local function list_all_files(path, files)
        for p in path:list_directory() do
            if fs.is_directory(p) then
                list_all_files(p, files)
            elseif fs.is_regular_file(p) then
                files[p:string()] = p:localpath():string()
            end
        end
    end

    list_all_files(root_dir, files)
    local file_dist = {
        root_dir = root_dir:string(),
        files = files
    }
    local mq_eid = world:singleton_entity_id "main_queue"
    local  layouhandle = declmgr.get "p2|c40niu|t20".handle
    local vid = viewidmgr.get "uiruntime"
    local vr = irq.view_rect(mq_eid)
    fbmgr.bind(vid, irq.frame_buffer(mq_eid))

    return {
        font = fontinfo,
        file_dist = file_dist,
        viewid = vid,
        shader = {
            font = assetmgr.load_fx {
                fs = "/pkg/ant.resources/shaders/font/fs_uifont.sc",
                vs = "/pkg/ant.resources/shaders/font/vs_uifont.sc",
            },
            image = assetmgr.load_fx {
                fs = "/pkg/ant.resources/shaders/ui/fs_image.sc",
                vs = "/pkg/ant.resources/shaders/ui/vs_image.sc",
            },
        },
        layout  = layouhandle,
        viewrect= vr,
    }
end

local rmlui_context
function rmlui_sys:post_init()
    local data = init_rmlui_data()
    rmlui_context = rmlui.init(data)
    for f in pairs(data.file_dist.files) do
        local ext = f:match ".+%.([%w_]+)$":lower()
        if ext == "otf" or ext == "ttf" then
            rmlui_context:load_font(f)
        end
    end
    rmlui_context:load "/pkg/ant.resources.binary/ui/test/src/demo.rml"
end

function rmlui_sys:ui_update()
    rmlui_context:render()
end

function rmlui_sys:exit()
    rmlui_context:shutdown()
end