local ecs = ...
local world = ecs.world
local prefab_mgr        = ecs.require "prefab_manager"
local projsetting_view  = require "widget.project_setting_view"
local camerasetting_view= ecs.require "widget.camera_setting_view"
local rhwi              = import_package "ant.hwi"
local editor_setting    = require "editor_setting"

local ImGui             = import_package "ant.imgui"
local lfs               = require "bee.filesystem"
local global_data       = require "common.global_data"
local access            = global_data.repo_access
local fs                = require "filesystem"
local uiutils           = require "widget.utils"
local faicons            = require "common.fa_icons"

local m = {}
local function show_select_light_dialog()
    local lightprefab = editor_setting.setting.light or ""
    if ImGui.MenuItem(faicons.ICON_FA_LIGHTBULB.." Light:".. lightprefab) then
        local prefab_filename = uiutils.get_open_file_path("Select Prefab", "prefab")
        if prefab_filename then
            local filename = access.virtualpath(global_data.repo, prefab_filename)
            if filename and fs.exists(fs.path(filename)) then
                editor_setting.setting.light = filename
                editor_setting.save()
                world:pub { "UpdateDefaultLight", true}
            end
        end
    end
end
local function show_select_blender_dialog()
    local blenderpath = editor_setting.setting.blender_path or ""
    if ImGui.MenuItem("BlenderPath:".. blenderpath) then
        local filedialog = require 'filedialog'
        local dialog_info = {
            Owner = rhwi.native_window(),
            Title = "Choose blender path"
        }
        local ok, choosepath = filedialog.open(dialog_info)
        if ok and choosepath[1] then
            local path = choosepath[1]
            if lfs.exists(lfs.path(path .. "\\blender.exe")) then
                editor_setting.setting.blender_path = path:gsub("\\", "/")
                editor_setting.save()
            end
        end
    end
end

function m.show()
    local click_project_setting
    local camera_setting
    if ImGui.BeginMainMenuBar() then
        if ImGui.BeginMenu "File" then
            if ImGui.MenuItem(faicons.ICON_FA_FILE_PEN.." New", "Ctrl+N") then
                prefab_mgr:reset_prefab()
            end
            if ImGui.MenuItem(faicons.ICON_FA_FOLDER_OPEN.." Open", "Ctrl+O") then
                world:pub{"OpenProject"}
            end
            ImGui.Separator()
            if ImGui.BeginMenu(faicons.ICON_FA_LIST.." Recent Files") then
                local rf = editor_setting.setting.recent_files
                if rf then
                    for _, f in ipairs(editor_setting.setting.recent_files) do
                        local ff = f:match "([^|]+)|mesh.prefab"
                        ff = ff or f
                        if fs.exists(fs.path(ff)) and ImGui.MenuItem(ff) then
                            world:pub{"OpenFile", ff}
                        end
                    end
                end
                ImGui.EndMenu()
            end
            ImGui.Separator()
            if ImGui.MenuItem(faicons.ICON_FA_FLOPPY_DISK.." Save", "Ctrl+S") then
                prefab_mgr:save()
            end
            
            -- if ImGui.MenuItem(faicons.ICON_FA_DOWNLOAD.." Save As..") then
            --     local path = widget_utils.get_saveas_path("Prefab", "prefab")
            --     if path then
            --         prefab_mgr:save(path)
            --     end
            -- end
            ImGui.EndMenu()
        end
        if ImGui.BeginMenu "Edit" then
            ImGui.Separator()
            if ImGui.MenuItem(faicons.ICON_FA_ARROW_ROTATE_LEFT.." Undo", "CTRL+Z") then
            end

            if ImGui.MenuItem(faicons.ICON_FA_ARROW_ROTATE_RIGHT.." Redo", "CTRL+Y", false, false) then
            end
            ImGui.Separator()
            if ImGui.MenuItem(faicons.ICON_FA_FLOPPY_DISK.. " SaveUILayout") then
                -- prefab_mgr:save_ui_layout()
                world:pub{"UILayout", "save"}
            end
            ImGui.Separator()
            if ImGui.MenuItem(faicons.ICON_FA_ARROWS_ROTATE.. " ResetUILayout") then
                -- prefab_mgr:reset_ui_layout()
                world:pub{"UILayout", "reset"}
            end
            show_select_light_dialog()
            show_select_blender_dialog()
            ImGui.Separator()
            if ImGui.MenuItem(faicons.ICON_FA_GEAR.." ProjectSetting") then
                click_project_setting = true
            end
            ImGui.EndMenu()
        end
        if ImGui.BeginMenu "Action" then
            if ImGui.BeginMenu "Lightmap..." then
                if ImGui.MenuItem "Bake" then
                    world:pub {"BakeLightmap", tostring(prefab_mgr.prefab)}
                end
                ImGui.EndMenu()
            end

            ImGui.Separator()
            
            if ImGui.MenuItem(faicons.ICON_FA_GEAR .. camerasetting_view.viewname) then
                camera_setting = true
            end

            ImGui.EndMenu()
        end
      
        ImGui.EndMainMenuBar()
    end

    camerasetting_view.show(camera_setting)
    projsetting_view.show(click_project_setting)
end

return m