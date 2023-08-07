local fs = require "filesystem.local"
local GLTF2OZZ = require "editor.tool_exe_path"("gltf2ozz")
local subprocess = require "editor.subprocess"

return function (status)
    local input = status.input
    local output = status.output
    local folder = output / "animations"
    fs.create_directories(folder)
    -- we can specify config file to determine what skeleton file name and animaiton name
    -- it json file:
    --[[
        {
            skeleton = {
                filename = "aaa.ozz"
            },
            animations = [
                {filename="abc.ozz"}
                ...
            ]
        }
    ]]
    local cwd = fs.current_path()
    print("animation compile:")
    local success, msg = subprocess.spawn_process {
        GLTF2OZZ,
        "--file=" .. (cwd / input):string(),
        cwd = folder:string(),
    }

    if not success then
        print(msg)
    end
    local skefile = folder / "skeleton.ozz"
    if not fs.exists(skefile) then
        print("NO SKELETON export!")
    else
        status.skeleton = "animations/skeleton.ozz"
    end

    status.animations = {}
    for path in fs.pairs(folder) do
        if path:equal_extension ".ozz" then
            local filename = path:filename():string()
            if filename ~= "skeleton.ozz" then
                status.animations[path:stem():string()] = "animations/"..filename
            end
        end
    end
end
