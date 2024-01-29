local ecs = ...
local world = ecs.world
local w = world.w

local vfs = require "vfs"
local fs = require "filesystem"
local lfs = require "bee.filesystem"
local subprocess = require "bee.subprocess"
local ImGui = import_package "ant.imgui"
local editor_setting    = require "editor_setting"


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
    if not ImGui.IsPopupOpen(title) then
        ImGui.OpenPopup(title)
    end

    local change, opened = ImGui.BeginPopupModal(title, true, ImGui.Flags.Window{"AlwaysAutoResize"})
    if change then
        ImGui.Text("Create new or open existing project.")
        if ImGui.Button(ICON_FA_FOLDER_PLUS.." Create") then
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
        ImGui.SameLine()
        if ImGui.Button(ICON_FA_FOLDER_OPEN.." Open") then
            local path = choose_project_dir()
            if path then
                do_open_proj(path)
                exit = true
            end
        end
        ImGui.SameLine()
        if ImGui.Button(ICON_FA_BAN.." Quit") then
            exit = true
        end

        ImGui.Separator()
        if lastprojs then
            for i, proj in ipairs(lastprojs) do
                if ImGui.Selectable(proj.name .. " : " .. proj.proj_path, selected_proj and selected_proj.proj_path == proj.proj_path, ImGui.Flags.Selectable {"AllowDoubleClick"}) then
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
        --     ImGui.CloseCurrentPopup()
        -- end
        ImGui.EndPopup()
    end
    return exit
end

local m = ecs.system 'init_system'

function m:init_system()
    local rf = io.open(lfs.path(vfs.repopath()):string().. "/pkg/launch/imgui.layout", "rb")
    if rf then
        local setting = rf:read "a"
        rf:close()
        ImGui.LoadIniSettings(setting)
    end
end

function m:data_changed()
    local imgui_vp = ImGui.GetMainViewport()
    local s = imgui_vp.Size
    local wp, ws = imgui_vp.WorkPos, imgui_vp.WorkSize
    ImGui.SetNextWindowPos(wp[1], wp[2])
    ImGui.SetNextWindowSize(ws[1], ws[2])
    ImGui.SetNextWindowViewport(imgui_vp.ID)
	ImGui.PushStyleVar(ImGui.Enum.StyleVar.WindowRounding, 0.0);
	ImGui.PushStyleVar(ImGui.Enum.StyleVar.WindowBorderSize, 0.0);
    ImGui.PushStyleVar(ImGui.Enum.StyleVar.WindowPadding, 0.0, 0.0);
    if ImGui.Begin("MainView", nil, ImGui.Flags.Window {
        "NoDocking",
        "NoTitleBar",
        "NoCollapse",
        "NoResize",
        "NoMove",
        "NoBringToFrontOnFocus",
        "NoNavFocus",
        "NoBackground",
    }) then
        ImGui.DockSpace("MainViewSpace", ImGui.Flags.DockNode {
            "NoDockingOverCentralNode",
            "PassthruCentralNode",
        })
    end
    ImGui.PopStyleVar(3)
    ImGui.End()

    local viewport = ImGui.GetMainViewport()
    ImGui.SetNextWindowPos(viewport.WorkPos[1], viewport.WorkPos[2], 'F')
    ImGui.SetNextWindowSize(viewport.WorkSize[1], viewport.WorkSize[2], 'F')
    -- ImGui.SetNextWindowDockID("MainViewSpace", 'F')
    local exit = false
    if ImGui.Begin("##Choose project", true, ImGui.Flags.Window {"NoResize", "NoTitleBar", "NoCollapse" }) then
        -- exit = choose_project()
        -- local wid = ImGui.GetID("Choose project")
        local selected_proj
        local lastprojs = editor_setting.setting.lastprojs
        ImGui.Text("Create new or open existing project.")
        if ImGui.Button(ICON_FA_FOLDER_PLUS.." Create") then
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
        ImGui.SameLine()
        if ImGui.Button(ICON_FA_FOLDER_OPEN.." Open") then
            local path = choose_project_dir()
            if path then
                do_open_proj(path)
                exit = true
            end
        end
        ImGui.SameLine()
        if ImGui.Button(ICON_FA_BAN.." Quit") then
            exit = true
        end

        ImGui.Separator()
        if lastprojs then
            for i, proj in ipairs(lastprojs) do
                if ImGui.Selectable(proj.name .. " : " .. proj.proj_path, selected_proj and selected_proj.proj_path == proj.proj_path, ImGui.Flags.Selectable {"AllowDoubleClick"}) then
                    selected_proj = lastprojs[i]
                    do_open_proj(selected_proj.proj_path)
                    exit = true
                end
            end
        end
    end
    ImGui.End()
    if exit then
        -- local setting = ImGui.SaveIniSettings()
        -- local wf = assert(io.open("D:/Github/ant/tools/editor/launch/pkg/launch/imgui.layout", "wb"))
        -- wf:write(setting)
        -- wf:close()
        os.exit()
    end
end
