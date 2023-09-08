local lfs  = require "bee.filesystem"
local fs   = require "filesystem"
local sp   = require "bee.subprocess"
local task = require "task"

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

return function (input, output)
    local inputPath = lfs.path(input)
    local outputPath = fs.path(output):localpath()
    lfs.remove_all(outputPath:parent_path())
    lfs.create_directories(outputPath:parent_path())
    if inputPath:equal_extension ".fbx" then
        import_fbx(inputPath, outputPath)
    elseif inputPath:equal_extension ".glb" then
        lfs.copy_file(inputPath, outputPath, fs.copy_options.overwrite_existing)
    else
        error "unsupport file format"
        return
    end
end
