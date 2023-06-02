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

lm:source_set "dummy_main" {
    sources = "examples/dummy_main.c"
}

function m.example_target(name)
    local use_main = lm.os ~= 'android'
    local func = use_main and lm:exe(name) or lm:dll(name)
    return function (t)
        if use_main then
            t.defines = 'ENTRY_CONFIG_IMPLEMENT_MAIN=1'
        else
            t.basename = "lib"..name
            if name ~= "25-c99" then
                if t.deps then
                    table.insert(t.deps, "dummy_main")
                else
                    t.deps = {
                        "dummy_main"
                    }
                end
            end
        end
        return func(t)
    end
end

return m
