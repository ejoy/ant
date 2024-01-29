local ecs = ...
local world = ecs.world
local assetmgr  = import_package "ant.asset"

local ImGui     = import_package "ant.imgui"
local lfs       = require "bee.filesystem"
local fs        = require "filesystem"
local uiconfig  = require "widget.config"
local utils     = require "common.utils"
local icons     = require "common.icons"
local faicons   = require "common.fa_icons"
local editor_setting=require "editor_setting"
local global_data = require "common.global_data"
local m = {
    dirty = true
}

local resource_tree = nil
local selected_folder = {files = {}}
local selected_file = nil

local preview_images = {}
local texture_detail = {}

local function on_drop_files(files)
    local current_path = lfs.path(tostring(selected_folder[1]))
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
        for item in lfs.pairs(fspath) do
            sorted_path[#sorted_path+1] = item
        end
        table.sort(sorted_path, function(a, b) return string.lower(tostring(a)) < string.lower(tostring(b)) end)
        for _, item in ipairs(sorted_path) do
            local ext = item:extension():string()
            if lfs.is_directory(item) and ext ~= ".glb" and ext ~= ".gltf" and ext ~= ".material" and ext ~= ".texture" then
                table.insert(tree.dirs, {item, construct_resource_tree(item), parent = {tree}})
                if selected_folder[1] == item then
                    selected_folder = tree.dirs[#tree.dirs]
                end
            else
                table.insert(tree.files, item)
            end
        end
    end
    return tree
end

local engine_package_resources = {
    "ant.resources",
    "ant.resources.binary",
}

function m.update_resource_tree(hiden_engine_res)
    if not m.dirty or not global_data.project_root then return end
    resource_tree = {files = {}, dirs = {}}
    local packages
    if hiden_engine_res then
        packages = {}
        for _, p in ipairs(global_data.packages) do
            local isengine
            if p.name:sub(1, 4) == "ant." and p.name:sub(1, 8) ~= "ant.test" then
                isengine = true
            end
            if not isengine then
                packages[#packages+1] = p
            end
        end
    else
        packages = global_data.packages
    end
    for _, item in ipairs(packages) do
        local vpath = fs.path("/pkg") / fs.path(item.name)
        -- resource_tree.dirs[#resource_tree.dirs + 1] = {path, construct_resource_tree(path)}
        resource_tree.dirs[#resource_tree.dirs + 1] = {vpath, construct_resource_tree(item.path)}
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
    if not selected_folder[1] then
        selected_folder = resource_tree.dirs[1]
    end
    m.dirty = false
end

local renaming = false
local new_filename = {text = "noname"}
local function rename_file(file)
    if not renaming then return end

    if not ImGui.IsPopupOpen("Rename file") then
        ImGui.OpenPopup("Rename file")
    end

    local change = ImGui.BeginPopupModal("Rename file", nil, ImGui.Flags.Window{"AlwaysAutoResize"})
    if change then
        ImGui.Text("new name :")
        ImGui.SameLine()
        if ImGui.InputText("##NewName", new_filename) then
        end
        ImGui.SameLine()
        if ImGui.Button(faicons.ICON_FA_SQUARE_CHECK.." OK") then
            lfs.rename(file:localpath(), file:parent_path():localpath() / tostring(new_filename.text))
            renaming = false
        end
        ImGui.SameLine()
        if ImGui.Button(faicons.ICON_FA_SQUARE_XMARK.." Cancel") then
            renaming = false
        end
        ImGui.EndPopup()
    end
end

local function ShowContextMenu()
    if ImGui.BeginPopupContextItem(tostring(selected_file:filename())) then
        if ImGui.MenuItem(faicons.ICON_FA_UP_RIGHT_FROM_SQUARE.." Reveal in Explorer", "Alt+Shift+R") then
            os.execute("c:\\windows\\explorer.exe /select,"..selected_file:localpath():string():gsub("/","\\"))
        end
        if ImGui.MenuItem(faicons.ICON_FA_PEN.." Rename", "F2") then
            renaming = true
            new_filename.text = tostring(selected_file:filename())
        end
        ImGui.Separator()
        if ImGui.MenuItem(faicons.ICON_FA_TRASH.." Delete", "Delete") then
            lfs.remove(selected_file:localpath())
            selected_file = nil
        end
        ImGui.EndPopup()
    end
end

local key_mb    = world:sub {"keyboard"}
local filter_cache = {}
local function create_filter_cache(parent, dirs, files)
    local key = tostring(parent)
    if filter_cache[key] then
       return
    end
    local cache = {}
    local count = 0
    local offset = 0
    local offset_map = {}
    local function cache_path(path, at, pos)
        local str = tostring(path:filename())
        local prefix = string.upper(string.sub(str, 1, 1))
        if not at[prefix] then
            at[prefix] = {}
        end
        local t = at[prefix]
        t[#t + 1] = {path = path, pos = pos}
        return prefix, t
    end
    local pos = 1
    for _, v in pairs(dirs) do
        local k, t = cache_path(v[1], cache, pos)
        offset_map[k] = offset
        offset = offset + #t
        pos = pos + 1
    end
    for _, v in pairs(files) do
        local k, t = cache_path(v, cache, pos)
        offset_map[k] = offset
        offset = offset + #t
        pos = pos + 1
    end
    for _, value in pairs(cache) do
        count = count + #value
    end
    filter_cache[key] = {files_map = cache, count = count, offset_map = offset_map}
end
local current_filter_idx
local current_filter_key
local function get_filter_path(parent, key)
    if #key > 1 then
        return
    end
    local dirty = false
    if key ~= current_filter_key then
        current_filter_key = key
        current_filter_idx = 1
        dirty = true
    end
    local files_map = filter_cache[tostring(parent)].files_map
    local filter = files_map[current_filter_key]
    if not filter or #filter < 1 then
        return
    end
    if not dirty then
        current_filter_idx = current_filter_idx + 1
        if current_filter_idx > #filter then
            current_filter_idx = 1
        end
    end
    return filter[current_filter_idx].path, filter[current_filter_idx].pos
end
local access    = global_data.repo_access
local item_height
local function pre_init_item_height()
    if item_height then
        return
    end
    local _, pos_y = ImGui.GetCursorPos()
    item_height = -pos_y
end
local function post_init_item_height()
    if item_height and item_height > 0 then
        return
    end
    local _, pos_y = ImGui.GetCursorPos()
    item_height = pos_y + item_height
end

function m.get_title()
    return "ResourceBrowser"
end

function m.show()
    if not global_data.project_root then
        return
    end
    local dirtyflag = {}
    local type, path = global_data.filewatch:select()
    while type do
        if (not string.find(path, ".build"))
            and (not string.find(path, ".log"))
            and (not string.find(path, ".repo"))
            and (not string.find(path, "log.txt")) then
            m.dirty = true
        end
        type, path = global_data.filewatch:select()
        if path then
            local postfix = string.sub(path, -4)
            if (postfix == '.png' or postfix == '.dds') and not dirtyflag[path] then
                dirtyflag[path] = true
                world:pub {"FileWatch", type, access.virtualpath(global_data.repo, path:gsub('\\', '/'))}
            end
        end
    end

    local viewport = ImGui.GetMainViewport()
    ImGui.SetNextWindowPos(viewport.WorkPos[1], viewport.WorkPos[2] + viewport.WorkSize[2] - uiconfig.BottomWidgetHeight, 'F')
    ImGui.SetNextWindowSize(viewport.WorkSize[1], uiconfig.BottomWidgetHeight, 'F')
    m.update_resource_tree(editor_setting.setting.hide_engine_resource)

    local function do_show_browser(folder)
        for k, v in pairs(folder.dirs) do
            local dir_name = tostring(v[1]:filename())
            local base_flags = ImGui.Flags.TreeNode { "OpenOnArrow", "SpanFullWidth" } | ((selected_folder == v) and ImGui.Flags.TreeNode{"Selected"} or 0)
            local skip = false
            local fonticon = (not v.parent) and (faicons.ICON_FA_FILE_ZIPPER .. " ") or ""
            if (#v[2].dirs == 0) then
                ImGui.TreeNode(fonticon .. dir_name, base_flags | ImGui.Flags.TreeNode { "Leaf", "NoTreePushOnOpen" })
            else
                local adjust_flags = base_flags | (string.find(selected_folder[1]:string(), "/" .. dir_name) and ImGui.Flags.TreeNode {"DefaultOpen"} or 0)
                if ImGui.TreeNode(fonticon .. dir_name, adjust_flags) then
                    if ImGui.IsItemClicked() then
                        selected_folder = v
                    end
                    skip = true
                    do_show_browser(v[2])
                    ImGui.TreePop()
                end
            end
            if not skip and ImGui.IsItemClicked() then
                selected_folder = v
            end
        end 
    end

    if not selected_folder then
        return
    end
    
    if ImGui.Begin("ResourceBrowser", true, ImGui.Flags.Window { "NoCollapse", "NoScrollbar" }) then
        ImGui.PushStyleVar(ImGui.Enum.StyleVar.ItemSpacing, 0, 6)
        local relativePath
        if selected_folder[1]._value then
            relativePath = selected_folder[1]
        else
            relativePath = lfs.relative(selected_folder[1], global_data.project_root)
        end
        local _, split_dirs = path_split(relativePath:string())
        for i = 1, #split_dirs do
            if ImGui.Button("/" .. split_dirs[i]) then
                if tostring(selected_folder[1]:filename()) ~= split_dirs[i] then
                    local lookup_dir = selected_folder.parent
                    while lookup_dir do
                        if tostring(lookup_dir[1]:filename()) == split_dirs[i] then
                            selected_folder = lookup_dir
                            lookup_dir = nil
                        else
                            lookup_dir = lookup_dir.parent
                        end
                    end
                end
            end
            ImGui.SameLine() --last SameLine for 'HideEngineResource' button
        end
        local cb = {editor_setting.setting.hide_engine_resource}
        if ImGui.Checkbox("HideEngineResource", cb) then
            editor_setting.setting.hide_engine_resource = cb[1]
            editor_setting.save()
            m.dirty = true
            m.update_resource_tree(editor_setting.setting.hide_engine_resource)
        end
        ImGui.PopStyleVar(1)
        ImGui.Separator()
        local filter_focus1 = false
        local filter_focuse2 = false
        if ImGui.BeginTable("InspectorTable", 3, ImGui.Flags.Table {'Resizable', 'ScrollY'}) then
            ImGui.TableNextColumn()
            local child_width, child_height = ImGui.GetContentRegionAvail()
            ImGui.BeginChild("##ResourceBrowserDir", child_width, child_height)
            filter_focus1 = ImGui.IsWindowFocused()
            do_show_browser(resource_tree)
            ImGui.EndChild()

            ImGui.SameLine()
            ImGui.TableNextColumn()
            child_width, child_height = ImGui.GetContentRegionAvail()
            ImGui.BeginChild("##ResourceBrowserContent", child_width, child_height);
            
            local folder = selected_folder[2]
            if folder then
                filter_focuse2 = ImGui.IsWindowFocused()
                if filter_focuse2 then
                    create_filter_cache(selected_folder[1], folder.dirs, folder.files)
                    for _, key, press, status in key_mb:unpack() do
                        if #key == 1 and press == 1 then
                            -- local cache = filter_cache[tostring(selected_folder[1])]
                            -- local file_count = cache and cache.count or 0
                            local file_path, file_pos = get_filter_path(selected_folder[1], key)
                            if file_path then
                                local max_scrolly = ImGui.GetScrollMaxY()
                                -- local scroll_pos = ((file_pos - 1) / file_count) * max_scrolly
                                -- if file_pos > 1 then
                                --     scroll_pos = scroll_pos + 22
                                -- end
                                local _, sy = ImGui.GetWindowSize()
                                selected_file = file_path or selected_file
                                local current_pos = ImGui.GetScrollY()
                                local target_pos = file_pos * (item_height or 22)
                                if target_pos > current_pos + sy or target_pos < sy or target_pos < (current_pos - sy) then
                                    local newpos = target_pos - sy
                                    if newpos < 0 then
                                        newpos = 0
                                    end
                                    ImGui.SetScrollY(newpos)
                                end
                            end
                        end
                    end
                else
                    if current_filter_key then
                        current_filter_key = nil
                        -- selected_file = nil
                    end
                end
                rename_file(selected_file)
                local function pre_selectable(icon, noselected)
                    ImGui.PushStyleColor(ImGui.Enum.Col.HeaderActive, 0.0, 0.0, 0.0, 0.0)
                    if noselected then
                        ImGui.PushStyleColor(ImGui.Enum.Col.HeaderHovered, 0.0, 0.0, 0.0, 0.0)
                    else
                        ImGui.PushStyleColor(ImGui.Enum.Col.HeaderHovered, 0.26, 0.59, 0.98, 0.31)
                    end
                    local imagesize = icon.texinfo.width * icons.scale
                    ImGui.Image(assetmgr.textures[icon.id], imagesize, imagesize)
                    ImGui.SameLine()
                end
                local function post_selectable()
                    ImGui.PopStyleColor(2)

                end
                for _, path in pairs(folder.dirs) do
                    pre_selectable(icons.ICON_FOLD, selected_file ~= path[1])
                    pre_init_item_height()
                    if ImGui.Selectable(tostring(path[1]:filename()), selected_file == path[1], ImGui.Flags.Selectable {"AllowDoubleClick"}) then
                        selected_file = path[1]
                        current_filter_key = 1
                        if ImGui.IsMouseDoubleClicked(0) then
                            selected_folder = path
                        end
                    end
                    post_init_item_height()
                    post_selectable()
                    if selected_file == path[1] then
                        ShowContextMenu()
                    end
                end
                for _, path in pairs(folder.files) do
                    pre_selectable(icons:get_file_icon(tostring(path)), selected_file ~= path)
                    pre_init_item_height()
                    if ImGui.Selectable(tostring(path:filename()), selected_file == path, ImGui.Flags.Selectable {"AllowDoubleClick"}) then
                        selected_file = path
                        current_filter_key = 1
                        if ImGui.IsMouseDoubleClicked(0) then
                            local isprefab = path:equal_extension(".prefab")
                            if path:equal_extension(".gltf") or path:equal_extension(".glb") or path:equal_extension(".fbx") or isprefab then
                                world:pub {"OpenFile", tostring(path), isprefab}
                            elseif path:equal_extension ".material" then
                                local me = ecs.require "widget.material_editor"
                                me.open(path)
                            end
                        end
                        if path:equal_extension(".png") then
                            if not preview_images[selected_file] then
                                local pkg_path = path:string()
                                preview_images[selected_file] = assetmgr.resource(pkg_path, { compile = true })
                            end
                        end

                        if path:equal_extension(".texture") then
                            if not texture_detail[selected_file] then
                                local pkg_path = path:string()
                                texture_detail[selected_file] = utils.readtable(pkg_path)
                                local t = assetmgr.resource(pkg_path)
                                local s = t.sampler
                                preview_images[selected_file] = t._data
                            end
                        end
                    end
                    post_init_item_height()
                    post_selectable()
                    if selected_file == path then
                        ShowContextMenu()
                    end
                    if path:equal_extension(".material")
                        or path:equal_extension(".texture")
                        or path:equal_extension(".png")
                        or path:equal_extension(".dds")
                        or path:equal_extension(".prefab")
                        or path:equal_extension(".glb")
                        or path:equal_extension(".gltf")
                        or path:equal_extension(".efk")
                        or path:equal_extension(".lua") then
                        if ImGui.BeginDragDropSource() then
                            ImGui.SetDragDropPayload("DragFile", tostring(path))
                            ImGui.Text(tostring(path:filename()))
                            ImGui.EndDragDropSource()
                        end
                    end
                end
            end
            ImGui.EndChild()
            
            ImGui.SameLine()
            ImGui.TableNextColumn()
            child_width, child_height = ImGui.GetContentRegionAvail()
            ImGui.BeginChild("##ResourceBrowserPreview", child_width, child_height)
            if selected_file and (selected_file:equal_extension(".png") or selected_file:equal_extension(".texture")) then
                local preview = preview_images[selected_file]
                if preview then
                    if texture_detail[selected_file] then
                        ImGui.Text("image:" .. tostring(texture_detail[selected_file].path))
                    end
                    -- ImGui.Columns(2, "PreviewColumns", true)
                    ImGui.Text(preview.texinfo.width .. "x" .. preview.texinfo.height .. " ".. preview.texinfo.bitsPerPixel)
                    local width, height = preview.texinfo.width, preview.texinfo.height
                    if width > 180 then
                        width = 180
                    end
                    if height > 180 then
                        height = 180
                    end
                    ImGui.Image(assetmgr.textures[preview.id], width, height)
                    ImGui.SameLine()
                    local texture_info = texture_detail[selected_file] 
                    if texture_info then
                        ImGui.Text(("Compress:\n  android: %s\n  ios: %s\n  windows: %s \nSampler:\n  MAG: %s\n  MIN: %s\n  MIP: %s\n  U: %s\n  V: %s"):format( 
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
            ImGui.EndChild()
        ImGui.EndTable()
        end
        global_data.camera_lock = filter_focus1 or filter_focuse2
    end
    ImGui.End()
end

function m.selected_file()
    return selected_file
end

function m.selected_folder()
    return selected_folder
end

return m