local fs = require "filesystem.local"
local subprocess = import_package "ant.subprocess"

return function (input, output, exports)
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
    local success, msg = subprocess.spawn_process {
        subprocess.tool_exe_path "gltf2ozz",
        "--file=" .. (cwd / input):string(),
        cwd = folder,
    }

    if not success then
        print(msg)
    end
    local skefile = folder / "skeleton.ozz"
    if not fs.exists(skefile) then
        print("NO SKELETON export!")
    else
        exports.skeleton = "./animations/skeleton.ozz"
    end

    exports.animations = {}
    for path in fs.pairs(folder) do
        if path:equal_extension ".ozz" then
            local filename = path:filename():string()
            if filename ~= "skeleton.ozz" then
                exports.animations[path:stem():string()] = "./animations/"..filename
            end
        end
    end
end
