local ecs = ...
local world = ecs.world
local w = world.w

local widget_utils      = require "widget.utils"
local prefab_mgr        = ecs.require "prefab_manager"

local projsetting       = require "widget.project_setting"

local rhwi              = import_package "ant.hwi"
local editor_setting    = require "editor_setting"

local imgui             = require "imgui"
local lfs               = require "filesystem.local"
local fs                = require "filesystem"

local m = {}

local function show_select_blender_dialog()
    local blenderpath = editor_setting.setting.blender_path or ""
    if imgui.widget.MenuItem("BlenderPath:".. blenderpath) then
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
    if imgui.widget.BeginMainMenuBar() then
        if imgui.widget.BeginMenu "File" then
            if imgui.widget.MenuItem("New", "Ctrl+N") then
                prefab_mgr:reset_prefab()
            end
            if imgui.widget.MenuItem("Open", "Ctrl+O") then
            end
            imgui.cursor.Separator()
            if imgui.widget.BeginMenu "Recent Files" then
                local rf = editor_setting.setting.recent_files
                if rf then
                    for _, f in ipairs(editor_setting.setting.recent_files) do
                        local ff = f:match "([^|]+)|mesh.prefab"
                        ff = ff or f
                        if imgui.widget.MenuItem(ff) then
                            world:pub{"OpenPrefab", f}
                        end
                    end
                end
                imgui.widget.EndMenu()
            end
            imgui.cursor.Separator()
            if imgui.widget.MenuItem("Save", "Ctrl+S") then
                prefab_mgr:save_prefab()
            end
            
            if imgui.widget.MenuItem "Save As.." then
                local path = widget_utils.get_saveas_path("Prefab", "prefab")
                if path then
                    prefab_mgr:save_prefab(path)
                end
            end
            imgui.widget.EndMenu()
        end
        if imgui.widget.BeginMenu "Edit" then
            imgui.cursor.Separator()
            if imgui.widget.MenuItem("Undo", "CTRL+Z") then
            end

            if imgui.widget.MenuItem("Redo", "CTRL+Y", false, false) then
            end
            imgui.cursor.Separator()
            if imgui.widget.MenuItem "SaveUILayout" then
                local setting = imgui.util.SaveIniSettings()
                local wf = assert(lfs.open(fs.path "":localpath() .. "/" .. "imgui.layout", "wb"))
                wf:write(setting)
                wf:close()
            end
            show_select_blender_dialog()
            imgui.cursor.Separator()
            if imgui.widget.MenuItem "ProjectSetting" then
                click_project_setting = true
            end
            imgui.widget.EndMenu()
        end
        if imgui.widget.BeginMenu "Action" then
            if imgui.widget.BeginMenu "Lightmap..." then
                if imgui.widget.MenuItem "Bake" then
                    world:pub {"BakeLightmap", tostring(prefab_mgr.prefab)}
                end
                imgui.widget.EndMenu()
            end
            imgui.widget.EndMenu()
        end
        
        imgui.widget.EndMainMenuBar()
    end

    projsetting.show(click_project_setting)
end

return m