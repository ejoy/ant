local assetmgr 	= import_package "ant.asset"
local imgui     = require "imgui"
local faicons   = require "common.fa_icons"
local icons   = require "common.icons"
local m = {}

local function ONCE(t, s)
    if not s then return t end
end
local windiwsBegin = imgui.windows.Begin
local windiwsEnd = setmetatable({}, { __close = imgui.windows.End })

function m.imgui_windows(...)
	windiwsBegin(...)
	return ONCE, windiwsEnd, nil, windiwsEnd
end

function m.imguiBeginToolbar()
    imgui.windows.PushStyleColor(imgui.enum.Col.Button, 0, 0, 0, 0)
    imgui.windows.PushStyleColor(imgui.enum.Col.ButtonActive, 0, 0, 0, 0)
    imgui.windows.PushStyleColor(imgui.enum.Col.ButtonHovered, 0.5, 0.5, 0.5, 0)
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.ItemSpacing, 4, 0)
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.FramePadding, 0, 0)
end

function m.imguiEndToolbar()
    imgui.windows.PopStyleVar(2)
    imgui.windows.PopStyleColor(3)
end

local function imgui_tooltip(text, wrap)
    if imgui.util.IsItemHovered() then
        if imgui.widget.BeginTooltip() then
            imgui.widget.TextWrapped(text, wrap or 200)
            imgui.widget.EndTooltip()
        end
    end
end

function m.imguiToolbar(icon, tooltip, active)
    local bg_col
    if active then
        bg_col = {0, 0, 0, 1}
    else
        bg_col = {0.2, 0.2, 0.2, 1}
    end
	imgui.windows.PushStyleVar(imgui.enum.StyleVar.FramePadding, 2, 2);
    local iconsize = icon.texinfo.width * (icons.scale or 1.5)
    local r = imgui.widget.ImageButton(tooltip, assetmgr.textures[icon.id], iconsize, iconsize, {frame_padding = 2, bg_col = bg_col, tint_col = {1.0, 1.0, 1.0, 1.0}})
    imgui.windows.PopStyleVar(1);
    if tooltip then
        imgui_tooltip(tooltip)
    end
    return r
end

local message = {
    
}
function m.message_box(msg)
    message[#message + 1] = msg
end

function m.show_message_box()
    if #message < 1 then return end
    local level = 1
    local function do_show_message(msg)
        if not imgui.windows.IsPopupOpen(msg.title) then
            imgui.windows.OpenPopup(msg.title)
        end
        local change, opened = imgui.windows.BeginPopupModal(msg.title, imgui.flags.Window{"AlwaysAutoResize"})
        if change then
            imgui.widget.Text(msg.info)
            level = level + 1
            if level <= #message then
                do_show_message(message[level])
            end
            if imgui.widget.Button("Close") then
                message[level - 1] = nil
                imgui.windows.CloseCurrentPopup()
            end
            imgui.windows.EndPopup()
        end
    end
    do_show_message(message[level])
end

function m.confirm_dialog(info)
    imgui.windows.OpenPopup(info.title)
    local change, opened = imgui.windows.BeginPopupModal(info.title, imgui.flags.Window{"AlwaysAutoResize", "NoClosed"})
    if change then
        imgui.widget.Text(info.message)
        if imgui.widget.Button(faicons.ICON_FA_SQUARE_CHECK" OK") then
            info.answer = 1
            imgui.windows.CloseCurrentPopup()
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button(faicons.ICON_FA_SQUARE_XMARK" Cancel") then
            info.answer = 0
            imgui.windows.CloseCurrentPopup()
        end
        imgui.windows.EndPopup()
    end
end

local rhwi      = import_package "ant.hwi"

local filedialog    = require 'filedialog'
function m.get_saveas_path(filetype, extension)
    local dialog_info = {
        Owner = rhwi.native_window(),
        Title = "Save As..",
        FileTypes = {filetype, extension}
    }
    local ok, path = filedialog.save(dialog_info)
    if ok then
        local ext = "."..extension
        local len = #ext
        path = string.gsub(path, "\\", "/")
        if string.sub(path,-len) ~= ext then
            path = path .. ext
        end
        -- local pos = string.find(path, "%"..ext.."$")
        -- if #path > pos + #ext - 1 then
        --     path = string.sub(path, 1, pos + #ext - 1)
        -- end
        return path
    end
end

function m.get_open_file_path(filetype, extension)
    local dialog_info = {
        Owner = rhwi.native_window(),
        Title = "Open",
        FileTypes = extension and {filetype, extension} or filetype
    }
    local ok, path = filedialog.open(dialog_info)
    if ok then
        -- local ext = "."..extension
        -- path = string.gsub(path[1], "\\", "/") .. ext
        -- local pos = string.find(path, "%"..ext)
        -- if #path > pos + #ext - 1 then
        --     path = string.sub(path, 1, pos + #ext - 1)
        -- end
        -- return path
        return string.gsub(path[1], "\\", "/")
    end
end

local global_data	= require "common.global_data"

function m.load_imgui_layout(filename)
    local rf = io.open(filename:string(), "rb")
    if not rf then
        rf = io.open(tostring(global_data.editor_root) .. "/imgui.default.layout", "rb")
    end
    if rf then
        local setting = rf:read "a"
        rf:close()
        imgui.util.LoadIniSettings(setting)
    end
end

function m.save_ui_layout()
    local setting = imgui.util.SaveIniSettings()
    local wf = assert(io.open(tostring(global_data.editor_root) .. "/imgui.layout", "wb"))
    wf:write(setting)
    wf:close()
end

function m.reset_ui_layout()
    -- TODO: default.layout
    m.load_imgui_layout(tostring(global_data.editor_root) .. "/imgui.default.layout")
    -- local dockID = imgui.util.GetID("MainViewSpace")
    -- imgui.dock.BuilderRemoveNode(dockID)
    -- imgui.dock.BuilderAddNode(dockID, 0)
    -- local imgui_vp = imgui.GetMainViewport()
    -- local ms = imgui_vp.MainSize
    -- imgui.dock.BuilderSetNodeSize(dockID, ms[1], ms[1])
    -- --
    -- local splitID = dockID
    -- local dockLeft
    -- local dockRight
    -- local dockDown
    -- splitID, dockLeft = imgui.dock.BuilderSplitNode(splitID, 'L', 0.25)
    -- splitID, dockRight = imgui.dock.BuilderSplitNode(splitID, 'R', 0.25)
    -- splitID, dockDown = imgui.dock.BuilderSplitNode(splitID, 'D', 0.3)
    -- --
    -- imgui.dock.BuilderDockWindow(log_widget.get_title(), dockDown)
    -- imgui.dock.BuilderDockWindow(console_widget.get_title(), dockDown)
    -- imgui.dock.BuilderDockWindow(keyframe_view.get_title(), dockDown)
    -- imgui.dock.BuilderDockWindow(anim_view.get_title(), dockDown)
    -- imgui.dock.BuilderDockWindow(resource_browser.get_title(), dockDown)

    -- imgui.dock.BuilderDockWindow(scene_view.get_title(), dockLeft)
    -- imgui.dock.BuilderDockWindow(inspector.get_title(), dockRight)
    -- --
    -- imgui.dock.BuilderFinish(dockID)
end

return m