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

return {
    windows = windows
}
