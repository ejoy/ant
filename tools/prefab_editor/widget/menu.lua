local ecs = ...
local world = ecs.world

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

        if imgui.widget.BeginMenu "Debug" then
            if imgui.widget.MenuItem "Fix Srt" then
                local stringify = import_package "ant.serialize".stringify

                local datalist = require "datalist"

                local rootdir = fs.path "d:/work/vaststars2"

                local function readfile(f)
                    local ff<close> = lfs.open(f)
                    return ff:read "a"
                end

                local function writefile(f, c)
                    local ff<close> = lfs.open(f, "w")
                    ff:write(c)
                end

                local function list_all_files(p, op, skips)
                    if skips[p:string()] then
                        return
                    end
                    for f in fs.pairs(p) do
                        if fs.is_directory(f) then
                            list_all_files(f, op, skips)
                        else
                            op(f)
                        end
                    end
                end

                list_all_files(rootdir, function (f)
                    if f:equal_extension "prefab" then
                        local c = datalist.parse(readfile(f))
                        local changed
                        for _, p in ipairs(c) do
                            if p.data and p.data.scene and p.data.scene.srt then
                                local srt = p.data.scene.srt
                                p.data.scene.srt = nil
                                p.data.scene.s = srt.s
                                p.data.scene.r = srt.r
                                p.data.scene.t = srt.t
                                changed = true
                            end
                        end
                        if changed then
                            writefile(f, stringify(c))
                        end
                    end
                end, {
                    [(rootdir / "build"):string()] = true,
                    [(rootdir / "bin"):string()] = true,
                    [(rootdir / "3rd/ant/bin"):string()] = true,
                    [(rootdir / "3rd/ant/3rd"):string()] = true,
                })
            end
            imgui.widget.EndMenu()
        end
        
        imgui.widget.EndMainMenuBar()
    end

    projsetting.show(click_project_setting)
end

return m