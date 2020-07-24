local ecs = ...
local world     = ecs.world
local math3d    = require "math3d"
local imgui     = require "imgui"
local rhwi      = import_package 'ant.render'.hwi
local assetmgr  = import_package "ant.asset"
local iss = world:interface "ant.scene|iscenespace"
local iom = world:interface "ant.objcontroller|obj_motion"
local ies = world:interface "ant.scene|ientity_state"
local lfs  = require "filesystem.local"
local fs   = require "filesystem"
local vfs = require "vfs"
local prefab_view = require "prefab_view"
local entity_mgr = require "common.entity_mgr"


local function ONCE(t, s)
    if not s then return t end
end
local windiwsBegin = imgui.windows.Begin
local windiwsEnd = setmetatable({}, { __close = imgui.windows.End })
local function imgui_windows(...)
	windiwsBegin(...)
	return ONCE, windiwsEnd, nil, windiwsEnd
end

local function imgui_tooltip(text, wrap)
    if imgui.util.IsItemHovered() then
        imgui.widget.BeginTooltip()
        imgui.widget.TextWrapped(text, wrap or 200)
        imgui.widget.EndTooltip()
    end
end

local m = ecs.system 'gui_system'

local status = {
    GizmoMode = "select",
    GizmoSpace = "worldspace"
}

local function imguiBeginToolbar()
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.Button, 0, 0, 0, 0)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.ButtonActive, 0, 0, 0, 0)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.ButtonHovered, 0.5, 0.5, 0.5, 0)
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.ItemSpacing, 4, 0)
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.FramePadding, 0, 0)
end

local function imguiEndToolbar()
    imgui.windows.PopStyleVar(2)
    imgui.windows.PopStyleColor(3)
end

local function imguiToolbar(icon, tooltip, active)
    local bg_col
    if active then
        bg_col = {0, 0, 0, 1}
    else
        bg_col = {0.2, 0.2, 0.2, 1}
    end
    local r = imgui.widget.ImageButton(icon.handle, icon.texinfo.width, icon.texinfo.height,
                {frame_padding = 2, bg_col = bg_col, tint_col = {1.0, 1.0, 1.0, 1.0}})
    if tooltip then
        imgui_tooltip(tooltip)
    end
    return r
end
local WidgetStartY = 23
local toolBarHeight = 40
local SceneWidgetWidth <const> = 200
local PropertyWidgetWidth <const> = 320
local ResourceBrowserHeight <const> = 256
local eventGizmo = world:sub {"Gizmo"}
local eventScene = world:sub {"Scene"}
local uiData = {
    eid = {0, flags = imgui.flags.InputText{ "ReadOnly" }},
    name = {text = "noname"},
    pos = {0,0,0},
    rot = {0,0,0},
    scale = {1,1,1},
    state = {0},
    material = {text = "nomaterial"},
    mesh = {text = "nomesh"}
}


local gizmo
local cmd_queue

local SELECT <const> = 0
local MOVE <const> = 1
local ROTATE <const> = 2
local SCALE <const> = 3
local sourceEid = nil
local targetEid = nil

local function update_ui_transform(eid)
    if not eid then
        return
    end
    local s, r, t = math3d.srt(iom.srt(eid))
    local Pos = math3d.totable(t)
    uiData.pos[1] = Pos[1]
    uiData.pos[2] = Pos[2]
    uiData.pos[3] = Pos[3]

    local Rot = math3d.totable(math3d.quat2euler(r))
    uiData.rot[1] = math.deg(Rot[1])
    uiData.rot[2] = math.deg(Rot[2])
    uiData.rot[3] = math.deg(Rot[3])

    local Scale = math3d.totable(s)
    uiData.scale[1] = Scale[1]
    uiData.scale[2] = Scale[2]
    uiData.scale[3] = Scale[3]
end

local function on_select(eid)
    uiData.eid[1] = eid
    uiData.name.text = world[eid].name
    update_ui_transform(eid)
    uiData.state[1] = world[eid]._rendercache.state
    -- uiData.material.text = world[eid].material.filename
    -- uiData.mesh.text = world[eid].mesh.filename
end

local function is_editable(eid)
    if not iom.srt(eid) or
        not entity_mgr:is_visible(eid) or
        entity_mgr:is_locked(eid) then
        return false
    end
    return true
end

local icons = require "common.icons"(assetmgr)

local function show_scene_node(node)
    local base_flags = imgui.flags.TreeNode { "OpenOnArrow", "SpanFullWidth" } | ((gizmo.target_eid == node.eid) and imgui.flags.TreeNode{"Selected"} or 0)
    local name = world[node.eid].name
    local function select_or_move(eid)
        if imgui.util.IsItemClicked() then
            if is_editable(eid) then
                gizmo:set_target(eid)
            end
        end
        if imgui.widget.BeginDragDropSource() then
            imgui.widget.SetDragDropPayload("Drag", eid)
            imgui.widget.EndDragDropSource()
        end
        if imgui.widget.BeginDragDropTarget() then
            local payload = imgui.widget.AcceptDragDropPayload("Drag")
            if payload then
                sourceEid = tonumber(payload)
                targetEid = eid
            end
            imgui.widget.EndDragDropTarget()
        end
    end
    local function lock_visible(eid)
        imgui.cursor.NextColumn()
        local icon
        if entity_mgr:is_locked(eid) then
            icon = icons.ICON_LOCK
        else
            icon = icons.ICON_UNLOCK
        end
        imgui.util.PushID(eid)
        if imgui.widget.ImageButton(icon.handle, icon.texinfo.width, icon.texinfo.height) then
            entity_mgr:set_lock(eid, not entity_mgr:is_locked(eid))
            --world:pub { "EntityState", "lock", eid, entity_mgr:is_locked(eid) }
        end
        imgui.util.PopID()
        imgui.cursor.SameLine()
        if entity_mgr:is_visible(eid) then
            icon = icons.ICON_VISIBLE
        else
            icon = icons.ICON_UNVISIBLE
        end
        imgui.util.PushID(eid)
        if imgui.widget.ImageButton(icon.handle, icon.texinfo.width, icon.texinfo.height) then
            entity_mgr:set_visible(eid, not entity_mgr:is_visible(eid))
            ies.set_state(eid, "visible", entity_mgr:is_visible(eid))
            --world:pub { "EntityState", "visible", eid, entity_mgr:is_visible(eid) }
        end
        imgui.util.PopID()
        imgui.cursor.NextColumn()
    end
    if #node.children == 0 then
        imgui.widget.TreeNode(name, base_flags | imgui.flags.TreeNode { "Leaf", "NoTreePushOnOpen" })
        select_or_move(node.eid)
        lock_visible(node.eid)
    else
        local open = imgui.widget.TreeNode(name, base_flags)
        select_or_move(node.eid)
        lock_visible(node.eid)
        if open then
            for _, child in ipairs(node.children) do
                show_scene_node(child)
            end
            imgui.widget.TreePop()
        end
    end
end

local function showMenu()
    if imgui.widget.BeginMainMenuBar() then
        if imgui.widget.BeginMenu("File") then
            if imgui.widget.MenuItem("New", "Ctrl+N") then

            end
            if imgui.widget.MenuItem("Open", "Ctrl+O") then

            end
            if imgui.widget.MenuItem("Save", "Ctrl+S") then

            end
            if imgui.widget.MenuItem("Save As..") then

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

local localSpace = {}
local function showToolbar()
    local sw, sh = rhwi.screen_size()
    imgui.windows.SetNextWindowPos(0, WidgetStartY)
    imgui.windows.SetNextWindowSize(sw, toolBarHeight)
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowRounding, 0)
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowBorderSize, 0)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.WindowBg, 0.2, 0.2, 0.2, 1)
    for _ in imgui_windows("Controll", imgui.flags.Window { "NoTitleBar", "NoResize", "NoScrollbar", "NoMove", "NoDocking" }) do
        imguiBeginToolbar()
        -- if imguiToolbar(icons.ICON_UNDO, "Undo", false) then
        --     print("undo")
        --     world:pub { "GizmoMode", "undo" }
        -- end
        -- imgui.cursor.SameLine()
        -- if imguiToolbar(icons.ICON_REDO, "Redo", false) then
        --     print("redo")
        --     world:pub { "GizmoMode", "redo" }
        -- end
        -- imgui.cursor.SameLine()
        if imguiToolbar(icons.ICON_SELECT, "Select", status.GizmoMode == "select") then
            status.GizmoMode = "select"
            world:pub { "GizmoMode", "select" }
        end
        imgui.cursor.SameLine()
        if imguiToolbar(icons.ICON_MOVE, "Move", status.GizmoMode == "move") then
            status.GizmoMode = "move"
            world:pub { "GizmoMode", "move" }
        end
        imgui.cursor.SameLine()
        if imguiToolbar(icons.ICON_ROTATE, "Rotate", status.GizmoMode == "rotate") then
            status.GizmoMode = "rotate"
            world:pub { "GizmoMode", "rotate" }
        end
        imgui.cursor.SameLine()
        if imguiToolbar(icons.ICON_SCALE, "Scale", status.GizmoMode == "scale") then
            status.GizmoMode = "scale"
            world:pub { "GizmoMode", "scale" }
        end
        imgui.cursor.SameLine()
        if imgui.widget.Checkbox("LocalSpace", localSpace) then
            world:pub { "GizmoMode", "localspace", localSpace[1]}
        end
        -- if imguiToolbar(icons.ICON_WORLD, "WorldSpace", status.GizmoSpace == "worldspace") then
        --     status.GizmoSpace = "worldspace"
        --     world:pub { "GizmoMode", "worldspace"}
        -- end
        -- imgui.cursor.SameLine()
        -- if imguiToolbar(icons.ICON_LOCAL, "LocalSpace", status.GizmoSpace == "localspace") then
        --     status.GizmoSpace = "localspace"
        --     world:pub { "GizmoMode", "localspace"}
        -- end
        imguiEndToolbar()
    end
    imgui.windows.PopStyleColor()
    imgui.windows.PopStyleVar(2)
end

local function showSceneView()
    local sw, sh = rhwi.screen_size()
    imgui.windows.SetNextWindowPos(0, WidgetStartY + toolBarHeight, 'F')
    imgui.windows.SetNextWindowSize(SceneWidgetWidth, sh - ResourceBrowserHeight - (WidgetStartY + toolBarHeight), 'F')

    for _ in imgui_windows("Hierarchy", imgui.flags.Window { "NoCollapse", "NoScrollbar", "NoClosed" }) do
        if prefab_view.root.eid > 0 then
            imgui.cursor.Columns(2, "SceneColumns", true)
            imgui.cursor.SetColumnOffset(2, imgui.windows.GetWindowContentRegionWidth() - 60)
            sourceEid = nil
            targetEid = nil
            show_scene_node(prefab_view.root)
            imgui.cursor.NextColumn()
            if sourceEid and targetEid then
                prefab_view:set_parent(sourceEid, targetEid)
                local sourceWorldMat = iom.calc_worldmat(sourceEid)
                local targetWorldMat = iom.calc_worldmat(targetEid)
                iom.set_srt(sourceEid, math3d.mul(math3d.inverse(targetWorldMat), sourceWorldMat))
                iss.set_parent(sourceEid, targetEid)
            end
            imgui.cursor.Columns(1)
        end
    end
end

local function showInspector()
    local sw, sh = rhwi.screen_size()
    imgui.windows.SetNextWindowPos(sw - PropertyWidgetWidth, WidgetStartY + toolBarHeight, 'F')
    imgui.windows.SetNextWindowSize(PropertyWidgetWidth, sh - ResourceBrowserHeight - (WidgetStartY + toolBarHeight), 'F')
    
    local oldPos = nil
    local oldRot = nil
    local oldScale = nil
    
    for _ in imgui_windows("Inspector", imgui.flags.Window { "NoCollapse", "NoScrollbar", "NoClosed" }) do
        if gizmo.target_eid then
            if uiData.eid[1] ~= gizmo.target_eid then
                on_select(gizmo.target_eid)
            end
            imgui.widget.InputInt("EID", uiData.eid)
            if imgui.widget.InputText("Name", uiData.name) then
                world[uiData.eid[1]].name = tostring(uiData.name.text)
            end

            if imgui.widget.TreeNode("Transform", imgui.flags.TreeNode { "DefaultOpen" }) then
                if imgui.widget.InputFloat("Position", uiData.pos) then
                    oldPos = math3d.totable(iom.get_position(uiData.eid[1]))
                    gizmo:set_position(uiData.pos)
                end
                if imgui.widget.InputFloat("Rotate", uiData.rot) then
                    oldRot = math3d.totable(iom.get_rotation(uiData.eid[1]))
                    gizmo:set_rotation(uiData.rot)
                end
                if imgui.widget.InputFloat("Scale", uiData.scale) then
                    oldScale = math3d.totable(iom.get_scale(uiData.eid[1]))
                    gizmo:set_scale(uiData.scale)
                end
                imgui.widget.TreePop()
            end
            if imgui.widget.TreeNode("Material", imgui.flags.TreeNode { "DefaultOpen" }) then
                if imgui.widget.InputText("mtlFile", uiData.material) then
                    world[uiData.eid[1]].mesh = tostring(uiData.material.text)
                end
                if imgui.widget.BeginDragDropTarget() then
                    local payload = imgui.widget.AcceptDragDropPayload("Drag")
                    if payload then
                        print(payload)
                    end
                    imgui.widget.EndDragDropTarget()
                end
                imgui.widget.TreePop()
            end
            if imgui.widget.InputText("Name", uiData.mesh) then
                world[uiData.eid[1]].mesh = tostring(uiData.mesh.text)
            end
        end
    end
    if oldPos then
        cmd_queue:record {action = MOVE, eid = gizmo.target_eid, oldvalue = oldPos, newvalue = {currentPos[1], currentPos[2], currentPos[3]}}
        oldPos = nil
    elseif oldRot then
        cmd_queue:record {action = ROTATE, eid = gizmo.target_eid, oldvalue = oldRot, newvalue = {currentRot[1], currentRot[2], currentRot[3]}}
        oldRot = nil
    elseif oldScale then
        cmd_queue:record {action = SCALE, eid = gizmo.target_eid, oldvalue = oldScale, newvalue = {currentScale[1], currentScale[2], currentScale[3]}}
        oldScale = nil
    end
end

local resourceTree = nil
local resourceRoot = "D:/Github/ant/tools/prefab_editor"
local currentFolder = {files = {}}
local currentFile = nil

local dropFilesEvent = world:sub {"OnDropFiles"}
local previewImages = {}

local function on_drop_files(files)
    local current_path = lfs.path(tostring(currentFolder[1]))
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

local function showResourceBrowser()
    local sw, sh = rhwi.screen_size()
    imgui.windows.SetNextWindowPos(0, sh - ResourceBrowserHeight, 'F')
    imgui.windows.SetNextWindowSize(sw, ResourceBrowserHeight, 'F')
    local function constructResourceTree(fspath)
        local tree = {files = {}, dirs = {}}
        for item in fspath:list_directory() do
            local filename = tostring(fs.path(item):filename())
            if fs.is_directory(item) then
                table.insert(tree.dirs, {item, constructResourceTree(item), parent = {tree}})
            else
                table.insert(tree.files, item)
            end
        end
        return tree
    end

    if resourceTree == nil then
        local root_path = fs.path(resourceRoot)
        resourceTree = {files = {}, dirs = {{root_path, constructResourceTree(root_path)}}}
        local function set_parent(tree)
            for _, v in pairs(tree[2].dirs) do
                v.parent = tree
                set_parent(v)
            end
        end
        set_parent(resourceTree.dirs[1])
        currentFolder = resourceTree.dirs[1]
    end

    local function doShowBrowser(folder)
        for k, v in pairs(folder.dirs) do
            local dir_name = tostring(fs.path(v[1]):filename())
            local base_flags = imgui.flags.TreeNode { "OpenOnArrow", "SpanFullWidth" } | ((currentFolder == v) and imgui.flags.TreeNode{"Selected"} or 0)
            local skip = false
            if (#v[2].dirs == 0) then
                imgui.widget.TreeNode(dir_name, base_flags | imgui.flags.TreeNode { "Leaf", "NoTreePushOnOpen" })
            else
                local adjust_flags = base_flags | (string.find(currentFolder[1]._value, "/" .. dir_name) and imgui.flags.TreeNode {"DefaultOpen"} or 0)
                if imgui.widget.TreeNode(dir_name, adjust_flags) then
                    if imgui.util.IsItemClicked() then
                        currentFolder = v
                    end
                    skip = true
                    doShowBrowser(v[2])
                    imgui.widget.TreePop()
                end
            end
            if not skip and imgui.util.IsItemClicked() then
                currentFolder = v
            end
        end 
    end

    for _ in imgui_windows("ResourceBrowser", imgui.flags.Window { "NoCollapse", "NoScrollbar", "NoClosed" }) do
        imgui.windows.PushStyleVar(imgui.enum.StyleVar.ItemSpacing, 0, 6)
        imgui.widget.Button(tostring(fs.path(resourceRoot):parent_path()))
        imgui.cursor.SameLine()
        local _, split_dirs = path_split(tostring(fs.relative(currentFolder[1], fs.path(fs.path(resourceRoot):parent_path()))))
        for i = 1, #split_dirs do
            if imgui.widget.Button("/" .. split_dirs[i])then
                if tostring(currentFolder[1]:filename()) ~= split_dirs[i] then
                    local lookup_dir = currentFolder.parent
                    while lookup_dir do
                        if tostring(lookup_dir[1]:filename()) == split_dirs[i] then
                            currentFolder = lookup_dir
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

        imgui.windows.BeginChild("ResourceBrowserDir", width, height, false);
        doShowBrowser(resourceTree)
        imgui.windows.EndChild()
        imgui.cursor.SameLine()
        imgui.windows.BeginChild("ResourceBrowserContent", width * 3, height, false);
        local folder = currentFolder[2]
        if folder then
            for _, v in pairs(folder.files) do
                local icon = icons.get_file_icon(v)
                imgui.widget.Image(icon.handle, icon.texinfo.width, icon.texinfo.height)
                imgui.cursor.SameLine()
                local v_path = fs.path(v)
                if imgui.widget.Selectable(tostring(v_path:filename()), currentFile == v, 0, 0, imgui.flags.Selectable {"AllowDoubleClick"}) then
                    currentFile = v
                    if imgui.util.IsMouseDoubleClicked(0) then
                        local prefab_file
                        if v_path:equal_extension(".prefab") then
                            prefab_file = tostring(v_path)
                        elseif v_path:equal_extension(".glb") then
                            prefab_file = tostring(v_path) .. "|mesh.prefab"
                        end
                        world:pub {"instance_prefab", prefab_file}
                        
                    end
                    if v_path:equal_extension(".png") then
                        if not previewImages[currentFile] then
                            local rp = fs.relative(v_path, fs.path(resourceRoot))
                            local pkg_path = "/pkg/ant.tools.prefab_editor/" .. tostring(rp)
                            previewImages[currentFile] = assetmgr.resource(pkg_path, true)
                        end
                    end
                end
                
                if v_path:equal_extension(".material")
                    or v_path:equal_extension(".png")
                    or v_path:equal_extension(".prefab")
                    or v_path:equal_extension(".glb") then
                    if imgui.widget.BeginDragDropSource() then
                        imgui.widget.SetDragDropPayload("Drag", tostring(v))
                        imgui.widget.EndDragDropSource()
                    end
                end
            end
            for _, v in pairs(folder.dirs) do
                imgui.widget.Image(icons.ICON_FOLD.handle, icons.ICON_FOLD.texinfo.width, icons.ICON_FOLD.texinfo.height)
                imgui.cursor.SameLine()
                if imgui.widget.Selectable(tostring(fs.path(v[1]):filename()), currentFile == v[1], 0, 0, imgui.flags.Selectable {"AllowDoubleClick"}) then
                    currentFile = v[1]
                    if imgui.util.IsMouseDoubleClicked(0) then
                        currentFolder = v
                    end
                end
                
            end
        end
        imgui.windows.EndChild()
        imgui.cursor.SameLine()
        imgui.windows.BeginChild("ResourceBrowserPreview", width, height, false);
        
        
        if fs.path(currentFile):equal_extension(".png") then
            local preview = previewImages[currentFile]
            if preview then
                imgui.widget.Text(preview.texinfo.width .. "x" .. preview.texinfo.height .. " ".. preview.texinfo.format)
                imgui.widget.Image(preview.handle, preview.texinfo.width, preview.texinfo.height)
            end
            --imgui.widget.ImageButton(tex.handle)
        end
        imgui.windows.EndChild()
    end
    local payload = imgui.widget.GetDragDropPayload()
    if payload then
        print(payload)
    end
end

function m:ui_update()
    for _, action, value1, value2 in eventGizmo:unpack() do
        if action == "update" or action == "ontarget" then
            update_ui_transform(gizmo.target_eid)
        elseif action == "create" then
            gizmo = value1
            cmd_queue = value2
        end
    end
    
    for _, files in dropFilesEvent:unpack() do
        on_drop_files(files)
    end

    showMenu()
    showToolbar()
    imgui.showDockSpace(0, 62)
    showSceneView()
    showInspector()
    showResourceBrowser()
end

-- local function onDropFiles(files)
--     for _, file in ipairs(files) do
--         prefab_mgr:create_prefab(file)
--     end
-- end

-- local dragFiles = world:sub {"dropfiles"}

function m:data_changed()

    -- for _,files in dragFiles:unpack() do
    --     onDropFiles(files)
    -- end
end
