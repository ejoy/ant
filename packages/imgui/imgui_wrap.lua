local ENABLE_LUA_WRAP = true
local ENABLE_LUA_TRACE = false

--print error when tryint to index a unexist key
local function asset_index(tbl,path)
    return function( _,key )
        local v = tbl[key]
        if v then
            return v
        else
            print(string.format("[Imgui Error]:%s<%s> not exist!",path,key))
            print(debug.traceback())
        end
    end
end

local function wrap_table(tbl,path)
    path = path and (path..".") or ""
    local result = {}
    result = setmetatable(result,{__index = asset_index(tbl,path)})
    for k,v in pairs(tbl) do
        if type(v) == "table" then
            result[k] = wrap_table(v,path..k)
        end
    end
    return result
end

local imgui_c = require "bgfx.imgui"
local widget_c = imgui_c.widget
local flags_c = imgui_c.flags
local windows_c = imgui_c.windows
local util_c = imgui_c.util
local cursor_c = imgui_c.cursor
local enum_c = imgui_c.enum
local imgui_lua = setmetatable({},{__index=imgui_c})
imgui_lua.widget = setmetatable({},{__index=widget_c})
imgui_lua.flags = setmetatable({},{__index=flags_c})
imgui_lua.windows = setmetatable({},{__index=windows_c})
imgui_lua.util = setmetatable({},{__index=util_c})
imgui_lua.cursor = setmetatable({},{__index=cursor_c})
imgui_lua.enum = wrap_table(enum_c,"imgui.enum")

local function trace_call(src,dst,name)
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

if ENABLE_LUA_TRACE then
    trace_call(imgui_c,imgui_lua,"imgui")
    trace_call(widget_c,imgui_lua.widget,"imgui.widget")
    trace_call(flags_c,imgui_lua.flags,"imgui.flags")
    trace_call(windows_c,imgui_lua.windows,"imgui.windows")
    trace_call(util_c,imgui_lua.util,"imgui.util")
    trace_call(cursor_c,imgui_lua.cursor,"imgui.cursor")
end

if ENABLE_LUA_WRAP then
    return imgui_lua
else
    return imgui_c
end
