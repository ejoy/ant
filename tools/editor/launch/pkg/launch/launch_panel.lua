local bgfx      = require "bgfx"
local vfs       = require "vfs"
local fs        = require "filesystem"
local lfs       = require "bee.filesystem"
local subprocess = require "bee.subprocess"
local imgui = import_package "ant.imgui"

local editor_setting    = require "editor_setting"
local function init()
    local platform    = require "bee.platform"
	imgui.FontAtlasClear()
	if platform.os == "windows" then
		imgui.FontAtlasAddFont {
			SystemFont = "Segoe UI Emoji",
			SizePixels = 18,
			GlyphRanges = { 0x23E0, 0x329F, 0x1F000, 0x1FA9F }
		}
		imgui.FontAtlasAddFont {
			SystemFont = "黑体",
			SizePixels = 18,
			GlyphRanges = { 0x0020, 0xFFFF }
		}
		imgui.FontAtlasAddFont {
			FontPath = "/pkg/tools.editor/res/fonts/fa-solid-900.ttf",
			SizePixels = 16,
			GlyphRanges = {
				0xf05e, 0xf05e, -- ICON_FA_BAN 					"\xef\x81\x9e"	U+f05e
				0xf07c, 0xf07c, -- ICON_FA_FOLDER_OPEN 			"\xef\x81\xbc"	U+f07c
				0xf65e, 0xf65e, -- ICON_FA_FOLDER_PLUS 			"\xef\x99\x9e"	U+f65e
		}}
	elseif platform.os == "macos" then
		imgui.FontAtlasAddFont {
			SystemFont = "华文细黑",
			SizePixels = 18,
			GlyphRanges = { 0x0020, 0xFFFF }
		}
	else -- iOS
		imgui.FontAtlasAddFont {
			SystemFont = "Heiti SC",
			SizePixels = 18,
			GlyphRanges = { 0x0020, 0xFFFF }
		}
	end
	imgui.FontAtlasBuild()
    local rf = io.open(lfs.path(vfs.repopath()):string().. "/pkg/launch/imgui.layout", "rb")
    if rf then
        local setting = rf:read "a"
        rf:close()
        imgui.util.LoadIniSettings(setting)
    end
    -- local sx, sy = imgui.GetDisplaySize()
    -- imgui.SetWindowPos(math.floor((sx - 720) * 0.5), math.floor((sy - 450) * 0.5))
end

local function choose_project_dir()
    local filedialog = require 'filedialog'
    local dialog_info = {
        -- Owner = rhwi.native_window(),
        Title = "Choose project folder"
    }
    local ok, path = filedialog.open(dialog_info)
    if ok then
        return path[1]
    end
end

local function do_open_proj(proj_path)
    local exepath = lfs.exe_path():string()
    assert(subprocess.spawn {
        exepath,
        (string.sub(exepath, -7) == "lua.exe") and "tools/editor/main.lua" or "3rd/ant/tools/editor/main.lua",
        proj_path,
        -- console = "disable"
        detached = true
    })
    editor_setting.update_lastproj("", proj_path)
end

local ICON_FA_FOLDER_PLUS = "\xef\x99\x9e"
local ICON_FA_FOLDER_OPEN = "\xef\x81\xbc"
local ICON_FA_BAN = "\xef\x81\x9e"
local function choose_project()
    local exit = false;
    local selected_proj
    -- if global_data.project_root then return end
    local lastprojs = editor_setting.setting.lastprojs
    local title = "Choose project"
    if not imgui.windows.IsPopupOpen(title) then
        imgui.windows.OpenPopup(title)
    end

    local change, opened = imgui.windows.BeginPopupModal(title, imgui.flags.Window{"AlwaysAutoResize", "NoClosed"})
    if change then
        imgui.widget.Text("Create new or open existing project.")
        if imgui.widget.Button(ICON_FA_FOLDER_PLUS.." Create") then
            local path = choose_project_dir()
            if path then
                local lpath = lfs.path(path)
                local n = fs.pairs(lpath)
                -- if not n() then
                --     log_widget.error({tag = "Editor", message = "folder not empty!"})
                -- else
                --     on_new_project(path)
                --     global_data:update_root(lpath)
                --     editor_setting.update_lastproj("", path)
                -- end
            end
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button(ICON_FA_FOLDER_OPEN.." Open") then
            local path = choose_project_dir()
            if path then
                do_open_proj(path)
                exit = true
            end
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button(ICON_FA_BAN.." Quit") then
            exit = true
        end

        imgui.cursor.Separator()
        if lastprojs then
            for i, proj in ipairs(lastprojs) do
                if imgui.widget.Selectable(proj.name .. " : " .. proj.proj_path, selected_proj and selected_proj.proj_path == proj.proj_path, 0, 0, imgui.flags.Selectable {"AllowDoubleClick"}) then
                    selected_proj = lastprojs[i]
                    do_open_proj(selected_proj)
                    exit = true
                end
            end
        end
        -- if global_data.project_root then
        --     local bfw = require "bee.filewatch"
        --     local fw = bfw.create()
        --     fw:add(global_data.project_root:string())
        --     global_data.filewatch = fw
        --     log.warn "need handle effect file"
        --     imgui.windows.CloseCurrentPopup()
        -- end
        imgui.windows.EndPopup()
    end
    return exit
end

local function update(viewid)
    bgfx.set_view_clear(viewid, "CD", 0x303030ff, 1, 0)

    local imgui_vp = imgui.GetMainViewport()
    local s = imgui_vp.Size
    local wp, ws = imgui_vp.WorkPos, imgui_vp.WorkSize
    imgui.windows.SetNextWindowPos(wp[1], wp[2])
    imgui.windows.SetNextWindowSize(ws[1], ws[2])
    imgui.windows.SetNextWindowViewport(imgui_vp.ID)
	imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowRounding, 0.0);
	imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowBorderSize, 0.0);
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowPadding, 0.0, 0.0);
    if imgui.windows.Begin("MainView", imgui.flags.Window {
        "NoDocking",
        "NoTitleBar",
        "NoCollapse",
        "NoResize",
        "NoMove",
        "NoBringToFrontOnFocus",
        "NoNavFocus",
        "NoBackground",
    }) then
        imgui.dock.Space("MainViewSpace", imgui.flags.DockNode {
            "NoDockingOverCentralNode",
            "PassthruCentralNode",
        })
    end
    imgui.windows.PopStyleVar(3)
    imgui.windows.End()

    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1], viewport.WorkPos[2], 'F')
    imgui.windows.SetNextWindowSize(viewport.WorkSize[1], viewport.WorkSize[2], 'F')
    -- imgui.windows.SetNextWindowDockID("MainViewSpace", 'F')
    local exit = false
    if imgui.windows.Begin("##Choose project", imgui.flags.Window {"NoResize", "NoTitleBar", "NoCollapse", "NoClosed" }) then
        -- exit = choose_project()
        -- local wid = imgui.GetID("Choose project")
        local selected_proj
        local lastprojs = editor_setting.setting.lastprojs
        imgui.widget.Text("Create new or open existing project.")
        if imgui.widget.Button(ICON_FA_FOLDER_PLUS.." Create") then
            local path = choose_project_dir()
            if path then
                local lpath = lfs.path(path)
                local n = fs.pairs(lpath)
                -- if not n() then
                --     log_widget.error({tag = "Editor", message = "folder not empty!"})
                -- else
                --     on_new_project(path)
                --     global_data:update_root(lpath)
                --     editor_setting.update_lastproj("", path)
                -- end
            end
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button(ICON_FA_FOLDER_OPEN.." Open") then
            local path = choose_project_dir()
            if path then
                do_open_proj(path)
                exit = true
            end
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button(ICON_FA_BAN.." Quit") then
            exit = true
        end

        imgui.cursor.Separator()
        if lastprojs then
            for i, proj in ipairs(lastprojs) do
                if imgui.widget.Selectable(proj.name .. " : " .. proj.proj_path, selected_proj and selected_proj.proj_path == proj.proj_path, 0, 0, imgui.flags.Selectable {"AllowDoubleClick"}) then
                    selected_proj = lastprojs[i]
                    do_open_proj(selected_proj.proj_path)
                    exit = true
                end
            end
        end
    end
    imgui.windows.End()
    if exit then
        -- local setting = imgui.util.SaveIniSettings()
        -- local wf = assert(io.open("D:/Github/ant/tools/editor/launch/pkg/launch/imgui.layout", "wb"))
        -- wf:write(setting)
        -- wf:close()
        os.exit()
    end
end

return {
    init = init,
    update = update,
}
