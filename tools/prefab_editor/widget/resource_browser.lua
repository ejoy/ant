local imgui     = require "imgui"
local fw        = require "filewatch"
local lfs       = require "filesystem.local"
local fs        = require "filesystem"
local uiconfig  = require "widget.config"
local uiutils   = require "widget.utils"
local gd        = require "common.global_data"
local world
local assetmgr
local m = {
    dirty = true
}

local resource_tree = nil
local current_folder = {files = {}}
local current_file = nil

local preview_images = {}

local function on_drop_files(files)
    local current_path = lfs.path(tostring(current_folder[1]))
    for k, v in pairs(files) do
        local path = lfs.path(v)
        local dst_path = current_path / tostring(path:filename())
        if lfs.is_directory(path) then
            lfs.create_directories(dst_path)
            lfs.copy(path, dst_path, true)
        else
            lfs.copy_file(path, dst_path, true)
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
    local sorted_path = {}
    for item in fspath:list_directory() do
        sorted_path[#sorted_path+1] = item
    end
    table.sort(sorted_path, function(a, b) return tostring(a) < tostring(b) end)
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
    return tree
end

function m.update_resource_tree()
    if not m.dirty or not gd.resource_root then return end

    resource_tree = {files = {}, dirs = {{gd.resource_root, construct_resource_tree(gd.resource_root)}}}
    local function set_parent(tree)
        for _, v in pairs(tree[2].dirs) do
            v.parent = tree
            set_parent(v)
        end
    end
    set_parent(resource_tree.dirs[1])
    if not current_folder[1] then
        current_folder = resource_tree.dirs[1]
    end
    m.dirty = false
end

function m.show()
    if not gd.resource_root then
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

    local function doShowBrowser(folder)
        for k, v in pairs(folder.dirs) do
            local dir_name = tostring(v[1]:filename())
            local base_flags = imgui.flags.TreeNode { "OpenOnArrow", "SpanFullWidth" } | ((current_folder == v) and imgui.flags.TreeNode{"Selected"} or 0)
            local skip = false
            if (#v[2].dirs == 0) then
                imgui.widget.TreeNode(dir_name, base_flags | imgui.flags.TreeNode { "Leaf", "NoTreePushOnOpen" })
            else
                local adjust_flags = base_flags | (string.find(current_folder[1]._value, "/" .. dir_name) and imgui.flags.TreeNode {"DefaultOpen"} or 0)
                if imgui.widget.TreeNode(dir_name, adjust_flags) then
                    if imgui.util.IsItemClicked() then
                        current_folder = v
                    end
                    skip = true
                    doShowBrowser(v[2])
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
        imgui.widget.Button(tostring(gd.resource_root:parent_path()))
        imgui.cursor.SameLine()
        local _, split_dirs = path_split(tostring(fs.relative(current_folder[1], gd.resource_root:parent_path())))
        for i = 1, #split_dirs do
            if imgui.widget.Button("/" .. split_dirs[i])then
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

        local min_x, min_y = imgui.windows.GetWindowContentRegionMin()
        local max_x, max_y = imgui.windows.GetWindowContentRegionMin()
        local width = imgui.windows.GetWindowContentRegionWidth() * 0.2
        local height = (max_y - min_y) * 0.5

        imgui.windows.BeginChild("ResourceBrowserDir", width, height, false)
        doShowBrowser(resource_tree)
        imgui.windows.EndChild()
        imgui.cursor.SameLine()
        imgui.windows.BeginChild("ResourceBrowserContent", width * 3, height, false);
        local folder = current_folder[2]
        if folder then
            local icons = require "common.icons"(assetmgr)
            for _, path in pairs(folder.dirs) do
                imgui.widget.Image(icons.ICON_FOLD.handle, icons.ICON_FOLD.texinfo.width, icons.ICON_FOLD.texinfo.height)
                imgui.cursor.SameLine()
                if imgui.widget.Selectable(tostring(path[1]:filename()), current_file == path[1], 0, 0, imgui.flags.Selectable {"AllowDoubleClick"}) then
                    current_file = path[1]
                    if imgui.util.IsMouseDoubleClicked(0) then
                        current_folder = path
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
                        end
                        if prefab_file then
                            world:pub {"OpenPrefab", prefab_file}
                        end
                    end
                    if path:equal_extension(".png") then
                        if not preview_images[current_file] then
                            local rp = fs.relative(path, gd.resource_root)
                            local pkg_path = "/pkg/ant.tools.prefab_editor/" .. tostring(rp)
                            preview_images[current_file] = assetmgr.resource(pkg_path, { compile = true })
                        end
                    end
                end
                
                if path:equal_extension(".material")
                    or path:equal_extension(".texture")
                    or path:equal_extension(".png")
                    or path:equal_extension(".dds")
                    or path:equal_extension(".prefab")
                    or path:equal_extension(".glb") then
                    if imgui.widget.BeginDragDropSource() then
                        imgui.widget.SetDragDropPayload("DragFile", tostring(path))
                        imgui.widget.EndDragDropSource()
                    end
                end
            end
        end
        imgui.windows.EndChild()
        imgui.cursor.SameLine()
        imgui.windows.BeginChild("ResourceBrowserPreview", width, height, false);
        
        if fs.path(current_file):equal_extension(".png") then
            local preview = preview_images[current_file]
            if preview then
                imgui.widget.Text(preview.texinfo.width .. "x" .. preview.texinfo.height .. " ".. preview.texinfo.format)
                local width, height = preview.texinfo.width, preview.texinfo.height
                if width > 128 then
                    width = 128
                end
                if height > 128 then
                    height = 128
                end
                imgui.widget.Image(preview.handle, width, height)
            end
        end
        imgui.windows.EndChild()
    end
end

return function(w, am)
    world = w
    assetmgr = am
    return m
end