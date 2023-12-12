local lfs = require "bee.filesystem"
local GLTF2OZZ = require "tool_exe_path"("gltf2ozz")
local subprocess = require "subprocess"

return function (status)
    local gltfscene = status.glbdata.info
    local skins = gltfscene.skins
    if skins == nil then
        return
    end
    local input = status.input
    local output = status.output
    local folder = output / "animations"
    lfs.create_directories(folder)
    local cwd = lfs.current_path()
    print("animation compile:")
    local success, msg = subprocess.spawn_process {
        GLTF2OZZ,
        "--file=" .. (cwd / input):string(),
        "--config_file=" .. (cwd / "pkg/ant.compile_resource/model/gltf2ozz.json"):string(),
        cwd = folder:string(),
    }

    if not success then
        print(msg)
    end
    local skefile = folder / "skeleton.ozz"
    if not lfs.exists(skefile) then
        print("NO SKELETON export!")
    else
        status.skeleton = "animations/skeleton.ozz"
    end
    status.animations = {}
    for path in lfs.pairs(folder) do
        if path:equal_extension ".ozz" then
            local filename = path:filename():string()
            if filename:lower() ~= "skeleton.ozz" then
                local name = path:stem():string()
                assert(not name:match "[<>:/\\|?%s%[%]%(%)]")
                status.animations[name] = "animations/"..filename
            end
        end
    end
end
