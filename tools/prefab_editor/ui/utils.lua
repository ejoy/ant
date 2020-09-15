local imgui     = require "imgui"
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
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.Button, 0, 0, 0, 0)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.ButtonActive, 0, 0, 0, 0)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.ButtonHovered, 0.5, 0.5, 0.5, 0)
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.ItemSpacing, 4, 0)
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.FramePadding, 0, 0)
end

function m.imguiEndToolbar()
    imgui.windows.PopStyleVar(2)
    imgui.windows.PopStyleColor(3)
end

local function imgui_tooltip(text, wrap)
    if imgui.util.IsItemHovered() then
        imgui.widget.BeginTooltip()
        imgui.widget.TextWrapped(text, wrap or 200)
        imgui.widget.EndTooltip()
    end
end

function m.imguiToolbar(icon, tooltip, active)
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

function m.time2str(time)
    local fmt = "%Y-%m-%d %H:%M:%S:"
    local ti, tf = math.modf(time)
    return os.date(fmt, ti)..string.format("%03d",math.floor(tf*1000))
end

return m