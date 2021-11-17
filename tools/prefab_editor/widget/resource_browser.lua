local ecs = ...
local world = ecs.world
local w = world.w
local assetmgr  = import_package "ant.asset"

local imgui     = require "imgui"
local fw        = require "bee.filewatch"
local lfs       = require "filesystem.local"
local fs        = require "filesystem"
local uiconfig  = require "widget.config"
local uiutils   = require "widget.utils"
local utils     = require "common.utils"
local gd        = require "common.global_data"
local icons     = require "common.icons"(assetmgr)

local m = {
    dirty = true
}

local resource_tree = nil
local current_folder = {files = {}}
local current_file = nil

local preview_images = {}
local texture_detail = {}

local function on_drop_files(files)
    local current_path = lfs.path(tostring(current_folder[1]))
    for k, v in pairs(files) do
        local path = lfs.path(v)
        local dst_path = current_path / tostring(path:filename())
        if lfs.is_directory(path) then
            lfs.create_directories(dst_path)
            lfs.copy(path, dst_path, true)
        else
            lfs.copy_file(path, dst_path, fs.copy_options.overwrite_existing)
        end
    end
end

local function path_split(fullname)
    local root = (fullname:sub(1, 1) == "/") and "/" or ""
    local stack = {}
	for elem in fullname:gmatch("([^/\\]+)[/\\]?") do
        if #elem == 0 and #stack ~= 0 then
        elseif elem == '..' and #stack ~= 0 and stack[#stack] ~= '..' then
            stack[#stack] = nil
        elseif elem ~= '.' then
            stack[#stack + 1] = elem
        end
    end
    return root, stack
end

local function construct_resource_tree(fspath)
    local tree = {files = {}, dirs = {}}
    if fspath then
        local sorted_path = {}
        for item in fs.pairs(fspath) do
            sorted_path[#sorted_path+1] = item
        end
        table.sort(sorted_path, function(a, b) return string.lower(tostring(a)) < string.lower(tostring(b)) end)
        for _, item in ipairs(sorted_path) do
            if fs.is_directory(item) then
                table.insert(tree.dirs, {item, construct_resource_tree(item), parent = {tree}})
                if current_folder[1] == item then
                    current_folder = tree.dirs[#tree.dirs]
                end
            else
                table.insert(tree.files, item)
            end
        end
    end
    return tree
end

function m.update_resource_tree()
    if not m.dirty or not gd.project_root then return end
    resource_tree = {files = {}, dirs = {}}
    for _, item in ipairs(gd.packages) do
        local path = fs.path(item.name)
        resource_tree.dirs[#resource_tree.dirs + 1] = {path, construct_resource_tree(path)}
    end

    local function set_parent(tree)
        for _, v in pairs(tree[2].dirs) do
            v.parent = tree
            set_parent(v)
        end
    end

    for _, tree in ipairs(resource_tree.dirs) do
        set_parent(tree)
    end
    if not current_folder[1] then
        current_folder = resource_tree.dirs[1]
    end
    m.dirty = false
end

local renaming = false
local new_filename = {text = "noname"}
local function rename_file(file)
    if not renaming then return end

    if not imgui.windows.IsPopupOpen("Rename file") then
        imgui.windows.OpenPopup("Rename file")
    end

    local change, opened = imgui.windows.BeginPopupModal("Rename file", imgui.flags.Window{"AlwaysAutoResize"})
    if change then
        imgui.widget.Text("new name :")
        imgui.cursor.SameLine()
        if imgui.widget.InputText("##NewName", new_filename) then
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button("OK") then
            lfs.rename(file:localpath(), fs.path(tostring(file:parent_path() .. "/" .. tostring(new_filename.text))):localpath())
            renaming = false
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button("Cancel") then
            renaming = false
        end
        imgui.windows.EndPopup()
    end
end

function m.show()
    if not gd.project_root then
        return
    end
    local type, path = fw.select()
    while type do
        if (not string.find(path, "\\.build\\"))
            and (not string.find(path, "\\.log\\"))
            and (not string.find(path, "\\.repo\\")) then
            m.dirty = true
        end
        type, path = fw.select()
    end

    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1], viewport.WorkPos[2] + viewport.WorkSize[2] - uiconfig.BottomWidgetHeight, 'F')
    imgui.windows.SetNextWindowSize(viewport.WorkSize[1], uiconfig.BottomWidgetHeight, 'F')
    m.update_resource_tree()

    local function do_show_browser(folder)
        for k, v in pairs(folder.dirs) do
            local dir_name = tostring(v[1]:filename())
            local base_flags = imgui.flags.TreeNode { "OpenOnArrow", "SpanFullWidth" } | ((current_folder == v) and imgui.flags.TreeNode{"Selected"} or 0)
            local skip = false
            if not v.parent then
                imgui.widget.Image(icons.ICON_ROOM_INSTANCE.handle, icons.ICON_ROOM_INSTANCE.texinfo.width, icons.ICON_ROOM_INSTANCE.texinfo.height)
                imgui.cursor.SameLine()
            end
            if (#v[2].dirs == 0) then
                imgui.widget.TreeNode(dir_name, base_flags | imgui.flags.TreeNode { "Leaf", "NoTreePushOnOpen" })
            else
                local adjust_flags = base_flags | (string.find(current_folder[1]._value, "/" .. dir_name) and imgui.flags.TreeNode {"DefaultOpen"} or 0)
                if imgui.widget.TreeNode(dir_name, adjust_flags) then
                    if imgui.util.IsItemClicked() then
                        current_folder = v
                    end
                    skip = true
                    do_show_browser(v[2])
                    imgui.widget.TreePop()
                end
            end
            if not skip and imgui.util.IsItemClicked() then
                current_folder = v
            end
        end 
    end

    for _ in uiutils.imgui_windows("ResourceBrowser", imgui.flags.Window { "NoCollapse", "NoScrollbar", "NoClosed" }) do
        imgui.windows.PushStyleVar(imgui.enum.StyleVar.ItemSpacing, 0, 6)
        local _, split_dirs = path_split(current_folder[1]:string())
        for i = 1, #split_dirs do
            if imgui.widget.Button("/" .. split_dirs[i]) then
                if tostring(current_folder[1]:filename()) ~= split_dirs[i] then
                    local lookup_dir = current_folder.parent
                    while lookup_dir do
                        if tostring(lookup_dir[1]:filename()) == split_dirs[i] then
                            current_folder = lookup_dir
                            lookup_dir = nil
                        else
                            lookup_dir = lookup_dir.parent
                        end
                    end
                end
            end
            if i < #split_dirs then
                imgui.cursor.SameLine()
            end
        end
        imgui.windows.PopStyleVar(1)
        imgui.cursor.Separator()

        --imgui.deprecated.Columns(3)
        if imgui.table.Begin("InspectorTable", 3, imgui.flags.Table {'Resizable', 'ScrollY'}) then
            imgui.table.NextColumn()
            local child_width, child_height = imgui.windows.GetContentRegionAvail()
            imgui.windows.BeginChild("##ResourceBrowserDir", child_width, child_height, false)
            do_show_browser(resource_tree)
            imgui.windows.EndChild()

            imgui.cursor.SameLine()
            imgui.table.NextColumn()
            child_width, child_height = imgui.windows.GetContentRegionAvail()
            imgui.windows.BeginChild("##ResourceBrowserContent", child_width, child_height, false);
            local folder = current_folder[2]
            if folder then
                rename_file(current_file)
                for _, path in pairs(folder.dirs) do
                    imgui.widget.Image(icons.ICON_FOLD.handle, icons.ICON_FOLD.texinfo.width, icons.ICON_FOLD.texinfo.height)
                    imgui.cursor.SameLine()
                    if imgui.widget.Selectable(tostring(path[1]:filename()), current_file == path[1], 0, 0, imgui.flags.Selectable {"AllowDoubleClick"}) then
                        current_file = path[1]
                        if imgui.util.IsMouseDoubleClicked(0) then
                            current_folder = path
                        end
                    end
                    if current_file == path[1] then
                        if imgui.windows.BeginPopupContextItem(tostring(path[1]:filename())) then
                            if imgui.widget.Selectable("Delete", false) then
                                lfs.remove(current_file:localpath())
                                current_file = nil
                            end
                            if imgui.widget.Selectable("Rename", false) then
                                renaming = true
                                new_filename.text = tostring(current_file:filename())
                            end
                            imgui.windows.EndPopup()
                        end
                    end
                end
                for _, path in pairs(folder.files) do
                    local icon = icons.get_file_icon(path)
                    imgui.widget.Image(icon.handle, icon.texinfo.width, icon.texinfo.height)
                    imgui.cursor.SameLine()
                    if imgui.widget.Selectable(tostring(path:filename()), current_file == path, 0, 0, imgui.flags.Selectable {"AllowDoubleClick"}) then
                        current_file = path
                        if imgui.util.IsMouseDoubleClicked(0) then
                            local prefab_file
                            if path:equal_extension(".prefab") then
                                prefab_file = tostring(path)
                            elseif path:equal_extension(".glb") then
                                prefab_file = tostring(path) .. "|mesh.prefab"
                            elseif path:equal_extension(".fbx") then
                                world:pub {"OpenFBX", tostring(path)}
                            elseif path:equal_extension ".material" then
                                local me = ecs.require "widget.material_editor"
                                me.open(path)
                            end
                            if prefab_file then
                                world:pub {"OpenPrefab", prefab_file}
                            end
                        end
                        if path:equal_extension(".png") then
                            if not preview_images[current_file] then
                                local pkg_path = path:string()
                                preview_images[current_file] = assetmgr.resource(pkg_path, { compile = true })
                            end
                        end

                        if path:equal_extension(".texture") then
                            if not texture_detail[current_file] then
                                local pkg_path = path:string()
                                texture_detail[current_file] = utils.readtable(pkg_path)
                                local t = assetmgr.resource(pkg_path)
                                local s = t.sampler
                                preview_images[current_file] = t._data
                            end
                        end
                    end
                    if current_file == path then
                        if imgui.windows.BeginPopupContextItem(tostring(path:filename())) then
                            if imgui.widget.Selectable("Delete", false) then
                                lfs.remove(current_file:localpath())
                                current_file = nil
                            end
                            if imgui.widget.Selectable("Rename", false) then
                                renaming = true
                                new_filename.text = tostring(current_file:filename())
                            end
                            imgui.windows.EndPopup()
                        end
                    end
                    if path:equal_extension(".material")
                        or path:equal_extension(".texture")
                        or path:equal_extension(".png")
                        or path:equal_extension(".dds")
                        or path:equal_extension(".prefab")
                        or path:equal_extension(".glb")
                        or path:equal_extension(".efk")
                        or path:equal_extension(".lua") then
                        if imgui.widget.BeginDragDropSource() then
                            imgui.widget.SetDragDropPayload("DragFile", tostring(path))
                            imgui.widget.EndDragDropSource()
                        end
                    end
                end
            end
            imgui.windows.EndChild()

            imgui.cursor.SameLine()
            imgui.table.NextColumn()
            child_width, child_height = imgui.windows.GetContentRegionAvail()
            imgui.windows.BeginChild("##ResourceBrowserPreview", child_width, child_height, false);
            if fs.path(current_file):equal_extension(".png") or fs.path(current_file):equal_extension(".texture") then
                local preview = preview_images[current_file]
                if preview then
                    if texture_detail[current_file] then
                        imgui.widget.Text("image:" .. texture_detail[current_file].path)
                    end
                    -- imgui.deprecated.Columns(2, "PreviewColumns", true)
                    imgui.widget.Text(preview.texinfo.width .. "x" .. preview.texinfo.height .. " ".. preview.texinfo.format)
                    local width, height = preview.texinfo.width, preview.texinfo.height
                    if width > 180 then
                        width = 180
                    end
                    if height > 180 then
                        height = 180
                    end
                    imgui.widget.Image(preview.handle, width, height)
                    imgui.cursor.SameLine()
                    local texture_info = texture_detail[current_file] 
                    if texture_info then
                        imgui.widget.Text(("Compress:\n  android: %s\n  ios: %s\n  windows: %s \nSampler:\n  MAG: %s\n  MIN: %s\n  MIP: %s\n  U: %s\n  V: %s"):format( 
                            texture_info.compress and texture_info.compress.android or "raw",
                            texture_info.compress and texture_info.compress.ios or "raw",
                            texture_info.compress and texture_info.compress.windows or "raw",
                            texture_info.sampler.MAG,
                            texture_info.sampler.MIN,
                            texture_info.sampler.MIP,
                            texture_info.sampler.U,
                            texture_info.sampler.V
                            ))
                    end
                end
            end
            imgui.windows.EndChild()
        imgui.table.End()
        end
    end
end

return m