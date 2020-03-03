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

local checkbox_mt = {}
checkbox_mt.__index = checkbox_mt
function checkbox_mt:update()
    if self.selected then
        if imgui.widget.Selectable("√ "..self.label, true) then
            self.selected = false
            self:disable()
        end
    else
        if imgui.widget.Selectable("× "..self.label, false) then
            self.selected = true
            self:enable()
        end
    end
end

local function checkbox(t)
    return setmetatable(t, checkbox_mt)
end

return {
    windows = windows,
    checkbox = checkbox,
}
