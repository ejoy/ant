local ecs = ...
local world = ecs.world
local w = world.w

local widget_utils = require "widget.utils"
local prefab_mgr = ecs.require "prefab_manager"

local rhwi      = import_package "ant.hwi"
local stringify = import_package "ant.serialize".stringify

local imgui     = require "imgui"
local datalist  = require "datalist"
local lfs       = require "filesystem.local"
local fs        = require "filesystem"

local m = {}

local function show_select_blender_dialog()
    local settings_path = fs.path "editor.settings":localpath()
    local f = assert(lfs.open(settings_path))
    local data = f:read "a"
    f:close()
    
    -- local utils = require "common.utils"
    -- utils.write_file(tostring(settings_path), stringify({BlenderPath = "D:/blender-2.92.0"}))
    local settings = datalist.parse(data)
    if imgui.widget.MenuItem("BlenderPath:"..settings.BlenderPath) then
        local filedialog = require 'filedialog'
        local dialog_info = {
            Owner = rhwi.native_window(),
            Title = "Choose blender path"
        }
        local ok, choosepath = filedialog.open(dialog_info)
        if ok and choosepath[1] then
            local path = choosepath[1]
            if lfs.exists(lfs.path(path .. "\\blender.exe")) then
                settings.BlenderPath = path:gsub("\\", "/")
                local utils = require "common.utils"
                utils.write_file(tostring(settings_path), stringify(settings))
            end
        end
    end
end

local function show_project_setting(pid)
    
    if imgui.windows.OpenPopup ("test1", imgui.flags.Window {'AlwaysAutoResize'}) then
        local cb = {true}
        imgui.widget.Checkbox("abc1", cb)

        imgui.widget.InputFloat("bb", {1.0})
        imgui.windows.EndPopup()
    end
end

function m.show()
    if imgui.widget.BeginMainMenuBar() then
        if imgui.widget.BeginMenu "File" then
            if imgui.widget.MenuItem("New", "Ctrl+N") then
                prefab_mgr:reset_prefab()
            end
            if imgui.widget.MenuItem("Open", "Ctrl+O") then
            end
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

                show_project_setting("ProjectSetting")
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
end

return m