local lm = require "luamake"
local fs = require "bee.filesystem"

lm.bindir = ("bin/%s/%s"):format(lm.plat, lm.mode)

local Backlist = {}
local EditorModules = {}

for path in fs.path "clibs":list_directory() do
    if fs.exists(path / "make.lua") then
        local name = path:stem():string()
        if not Backlist[name] then
            lm:import(("clibs/%s/make.lua"):format(name))
            EditorModules[#EditorModules + 1] = name
        end
    end
end

lm:import "3rd/make.lua"
lm:import "runtime/make.lua"

lm:phony "runtime" {
    deps = "ant"
}

lm:phony "editor" {
    deps = {
        "lua",
        "luac",
        EditorModules
    }
}

lm:default "editor"
