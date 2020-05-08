local imgui = require "imgui.ant"

local function TOCLOSE(f)
    return setmetatable({}, { __close = f })
end

local function ONCE(t, s)
    if not s then return t end
end

local windiwsBegin = imgui.windows.Begin
local windiwsEnd = TOCLOSE(imgui.windows.End)

local function windows(...)
	windiwsBegin(...)
	return ONCE, windiwsEnd, nil, windiwsEnd
end

local function tooltip(text, wrap)
    if imgui.util.IsItemHovered() then
        imgui.widget.BeginTooltip()
        imgui.widget.TextWrapped(text, wrap or 200)
        imgui.widget.EndTooltip()
    end
end

return {
    windows = windows,
    tooltip = tooltip,
}
