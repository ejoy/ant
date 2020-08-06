local imgui = require "imgui"
local lfs   = require "filesystem.local"
local fs    = require "filesystem"

local m = {}
local prefab_mgr
function m.show()
    if imgui.widget.BeginMainMenuBar() then
        if imgui.widget.BeginMenu("File") then
            if imgui.widget.MenuItem("New", "Ctrl+N") then

            end
            if imgui.widget.MenuItem("Open", "Ctrl+O") then

            end
            if imgui.widget.MenuItem("Save", "Ctrl+S") then
                prefab_mgr:save_prefab()
            end
            if imgui.widget.MenuItem("Save As..") then
                local filedialog = require 'filedialog'
                local dialog_info = {
                    Owner = rhwi.native_window(),
                    Title = "Save As..",
                    FileTypes = {"Prefab", "*.prefab" }
                }
                local ok, path = filedialog.save(dialog_info)
                if ok then
                    prefab_mgr:save_prefab(path .. ".prefab")
                end
            end
            imgui.widget.EndMenu()
        end
        if imgui.widget.BeginMenu("Edit") then
            if imgui.widget.MenuItem("Undo", "CTRL+Z") then
            end

            if imgui.widget.MenuItem("Redo", "CTRL+Y", false, false) then
            end

            if imgui.widget.MenuItem("SaveUILayout") then
                local setting = imgui.util.SaveIniSettings()
                local current_path = lfs.current_path()
                local wf = assert(lfs.open(fs.path "":localpath() .. "/" .. "imgui.layout", "wb"))
                wf:write(setting)
                wf:close()
            end
            imgui.widget.EndMenu()
        end
        imgui.widget.EndMainMenuBar()
    end
end

return function(pm)
    prefab_mgr = pm
    return m
end