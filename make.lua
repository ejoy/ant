local lm = require "luamake"
local fs = require "bee.filesystem"

local plat = (function ()
    if lm.os == "windows" then
        if lm.compiler == "gcc" then
            return "mingw"
        end
        return "msvc"
    end
    return lm.os
end)()
lm.builddir = ("build/%s/%s"):format(plat, lm.mode)
lm.bindir = ("bin/%s/%s"):format(plat, lm.mode)

local EnableEditor = true
if lm.os == "ios" then
    lm.arch = "arm64"
    lm.vendor = "apple"
    lm.sys = "ios13.0"
    lm.compiler = "clang"
    EnableEditor = false
end

local Backlist = {}
local EditorModules = {}

for path in fs.path "clibs":list_directory() do
    if fs.exists(path / "make.lua") then
        local name = path:stem():string()
        if not Backlist[name] then
            lm:import(("clibs/%s/make.lua"):format(name))
            if EnableEditor then
                EditorModules[#EditorModules + 1] = name
            end
        end
    end
end

lm:import "3rd/make.lua"
lm:import "runtime/make.lua"

lm:phony "runtime" {
    deps = "ant"
}

if EnableEditor then
    lm:phony "editor" {
        deps = {
            "lua",
            "luac",
            EditorModules
        }
    }
    lm:default "editor"
else
    lm:default "runtime"
end
