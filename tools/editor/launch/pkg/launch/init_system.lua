local ecs = ...
local world = ecs.world
local w = world.w

local fs = require "filesystem"
local lfs = require "bee.filesystem"
local sys = require "bee.sys"
local subprocess        = require "bee.subprocess"
local ImGui             = require "imgui"
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
    local exepath = sys.exe_path():string()
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

local m = ecs.system 'init_system'

function m:init_system()
    local rf = io.open((lfs.current_path() / "tools/editor/pkg/launch/imgui.layout"):string(), "rb")
    if rf then
        local setting = rf:read "a"
        rf:close()
        ImGui.LoadIniSettingsFromMemory(setting)
    end
end

function m:data_changed()
    local viewport = ImGui.GetMainViewport()
    ImGui.SetNextWindowPos(viewport.WorkPos.x, viewport.WorkPos.y)
    ImGui.SetNextWindowSize(viewport.WorkSize.x, viewport.WorkSize.y)
    ImGui.SetNextWindowViewport(viewport.ID)
	ImGui.PushStyleVar(ImGui.StyleVar.WindowRounding, 0.0);
	ImGui.PushStyleVar(ImGui.StyleVar.WindowBorderSize, 0.0);
    ImGui.PushStyleVarImVec2(ImGui.StyleVar.WindowPadding, 0.0, 0.0);
    if ImGui.Begin("MainView", nil, ImGui.WindowFlags {
        "NoDocking",
        "NoTitleBar",
        "NoCollapse",
        "NoResize",
        "NoMove",
        "NoBringToFrontOnFocus",
        "NoNavFocus",
        "NoBackground",
    }) then
        ImGui.DockSpaceEx(ImGui.GetID "MainViewSpace", 0, 0, ImGui.DockNodeFlags {
            "NoDockingOverCentralNode",
            "PassthruCentralNode",
        })
    end
    ImGui.PopStyleVarEx(3)
    ImGui.End()

    viewport = ImGui.GetMainViewport()
    ImGui.SetNextWindowPos(viewport.WorkPos.x, viewport.WorkPos.y, ImGui.Cond.FirstUseEver)
    ImGui.SetNextWindowSize(viewport.WorkSize.x, viewport.WorkSize.y, ImGui.Cond.FirstUseEver)
    -- ImGui.SetNextWindowDockID("MainViewSpace", ImGui.Cond.FirstUseEver)
    local exit = false
    if ImGui.Begin("##Choose project", true, ImGui.WindowFlags {"NoResize", "NoTitleBar", "NoCollapse" }) then
        -- exit = choose_project()
        -- local wid = ImGui.GetID("Choose project")
        local selected_proj
        local lastprojs = editor_setting.setting.lastprojs
        ImGui.Text("Create new or open existing project.")
        if ImGui.Button("Create") then
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
        if ImGui.Button("Open") then
            local path = choose_project_dir()
            if path then
                do_open_proj(path)
                exit = true
            end
        end
        ImGui.SameLine()
        if ImGui.Button("Quit") then
            exit = true
        end

        ImGui.Separator()
        if lastprojs then
            for i, proj in ipairs(lastprojs) do
                if ImGui.SelectableEx(proj.name .. " : " .. proj.proj_path, selected_proj and selected_proj.proj_path == proj.proj_path, ImGui.SelectableFlags {"AllowDoubleClick"}) then
                    selected_proj = lastprojs[i]
                    do_open_proj(selected_proj.proj_path)
                    exit = true
                end
            end
        end
    end
    ImGui.End()
    if exit then
        -- local setting = ImGui.SaveIniSettingsToMemory()
        -- local wf = assert(io.open("D:/Github/ant/tools/editor/launch/pkg/launch/imgui.layout", "wb"))
        -- wf:write(setting)
        -- wf:close()
        os.exit()
    end
end
