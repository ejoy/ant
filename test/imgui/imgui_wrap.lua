local USE_LUA_WRAP = true


local imgui_c = require "bgfx.imgui"
local widget_c = imgui_c.widget
local flags_c = imgui_c.flags
local windows_c = imgui_c.windows
local util_c = imgui_c.util
local cursor_c = imgui_c.cursor
local imgui_lua = setmetatable({},{__index=imgui_c})
imgui_lua.widget = setmetatable({},{__index=widget_c})
imgui_lua.flags = setmetatable({},{__index=flags_c})
imgui_lua.windows = setmetatable({},{__index=windows_c})
imgui_lua.util = setmetatable({},{__index=util_c})
imgui_lua.cursor = setmetatable({},{__index=cursor_c})

local function check(value)
    if not value then
        print( debug.traceback() )
    end
end

local function wrap(src,dst,name)
    for k,v in pairs(src) do
        if type(v) == "function" then
            local f = dst[k]
            local function w(...)
                print(string.format("call function %s.%s",name, k),...)
                return f(...)
            end
            dst[k] = w
        end
    end
end

-- wrap(imgui_c,imgui_lua,"imgui")
-- wrap(widget_c,imgui_lua.widget,"imgui.widget")
-- wrap(flags_c,imgui_lua.flags,"imgui.flags")
-- wrap(windows_c,imgui_lua.windows,"imgui.windows")
-- wrap(util_c,imgui_lua.util,"imgui.util")
-- wrap(cursor_c,imgui_lua.cursor,"imgui.cursor")


if USE_LUA_WRAP then
    return imgui_lua
else
    return imgui_c
end
