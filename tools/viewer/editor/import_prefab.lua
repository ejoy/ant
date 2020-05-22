local lfs  = require "filesystem.local"
local fs   = require "filesystem"
local sp   = require "subprocess"
local task = require "task"
local cr   = import_package "ant.compile_resource"

local function import_fbx(input, output)
    local function luaexe()
        local i = -1
        while arg[i] ~= nil do
            i= i - 1
        end
        return arg[i + 1]
    end
    local p = sp.spawn {
        luaexe(),
        "./tools/import_fbx/import.lua",
        "-i", input,
        "-o", output,
        stderr = true,
        hideWindow = true,
    }
    while p:is_running() do
        task.wait(100)
    end
    assert(p:wait() == 0, p.stderr:read "a")
end

return function (filename)
    local output = "/pkg/tools.viewer.prefab_viewer/res/root.glb"
    local linput = lfs.path(filename)
    local loutput = fs.path(output):localpath()
    lfs.remove_all(loutput)
    lfs.create_directories(loutput:parent_path())
    if linput:equal_extension ".fbx" then
        import_fbx(linput, loutput)
    else
        lfs.copy_file(linput, loutput, true)
    end
    cr.clean(output)
    return output .. "|mesh.prefab"
end
