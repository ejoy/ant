local lfs  = require "filesystem.local"
local fs   = require "filesystem"
local sp   = require "subprocess"
local task = require "task"

local function import(input, voutput)
    local function luaexe()
        local i = -1
        while arg[i] ~= nil do
            i= i - 1
        end
        return arg[i + 1]
    end
    local loutput = voutput:localpath()
    lfs.remove_all(loutput)
    lfs.create_directories(loutput)
    local p = sp.spawn {
        luaexe(),
        "./tools/import_model/import.lua",
        "-i", input,
        "-o", loutput,
        "-v", voutput:string(),
        "--config", "tools/import_model/cfg.txt",
        stderr = true,
        hideWindow = true,
    }
    while p:is_running() do
        task.wait(100)
    end
    assert(p:wait() == 0, p.stderr:read "a")
end

return function (filename)
    local output = fs.path "/pkg/tools.viewer.prefab_viewer/res/"
    import(lfs.path(filename), output)
    return (output / "mesh.prefab"):string()
end
