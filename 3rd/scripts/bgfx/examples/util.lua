local lm = require "luamake"

local m = {}

local tools_dir = (function ()
    if lm.hostos == lm.os then
        return "$bin/"
    end
    if lm.hostos == "windows" then
        return ("build/msvc/%s/bin/"):format(lm.mode)
    end
    return ("build/%s/%s/bin/"):format(lm.hostos, lm.mode)
end)()

function m.tools_path(name)
    if lm.hostos == "windows" then
        return tools_dir..name..".exe"
    end
    return tools_dir..name
end

function m.example_target(name)
    if lm.os == 'android' then
        return lm:dll(name)
    else
        return lm:exe(name)
    end
end

return m
