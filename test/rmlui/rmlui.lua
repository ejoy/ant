local ecs = ...

local assetmgr = import_package "ant.asset"

local bgfx      = require "bgfx"
local bgfxutil  = require "bgfx.util"
local font      = require "font"
local fs        = require "filesystem"
local rmlui     = require "rmlui"

local ifont     = world:interface "ant.render|ifont"

local rmlui_sys = ecs.system "rmlui_system"

local function init_rmlui_data()
    local hwi = {
        create_texture = bgfxutil.create_texture,
        create_texture2d = bgfxutil.create_texture2d,
        destroy_texture = bgfxutil.destroy_texture,
    }

    local ft_w, ft_h = ifont.font_tex_dim()
    local fontinfo = {
        font_mgr = ifont.handle(),
        font_texture = {
            texid = ifont.font_tex_handle(),
            w = ft_w, h = ft_h,
        },
    }

    local root_dir = fs.path "/pkg/ant.resources.binary/ui/test"
    local files = {}
    local function list_all_files(path, files)
        for p in path:list_directory() do
            if fs.is_directory(p) then
                list_all_files(p, files)
            elseif fs.is_regular_file(p) then
                files[#files+1] = p:localpath():string()
            end
        end
    end

    list_all_files(root_dir, files)
    local file_dist = {
        root_dir = root_dir:string(),
        files = files
    }

    return {
        hwi = hwi,
        font = fontinfo,
        file_dist = file_dist,
        shader = {
            font = assetmgr.load_fx {
                fs = "/pkg/ant.resources/shaders/font/fs_uifont.sc",
                vs = "/pkg/ant.resources/shaders/font/vs_uifont.sc",
            },
            image = assetmgr.load_fx {
                fs = "/pkg/ant.resources/shaders/ui/fs_image.sc",
                vs = "/pkg/ant.resources/shaders/ui/vs_image.sc",
            },
        }
    }
end

local rmlui_context
function rmlui_sys:init()
    rmlui_context = rmlui.init(init_rmlui_data())
end

function rmlui_sys:ui_update()
    rmlui_context:update()
    rmlui_context:render()
end