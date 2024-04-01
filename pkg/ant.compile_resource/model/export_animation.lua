local lfs = require "bee.filesystem"
local GLTF2OZZ = require "tool_exe_path"("gltf2ozz")
local subprocess = require "subprocess"
local fastio = require "fastio"
local ozz = require "ozz"

return function (status)
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
    if not lfs.exists(folder / "skeleton.bin") then
        error("NO SKELETON export!")
    end
    status.skeleton = ozz.load(fastio.readall_f((folder / "skeleton.bin"):string()))
    local list = {}
    for path in lfs.pairs(folder) do
        if path:equal_extension ".bin" then
            local filename = path:filename():string()
            if filename ~= "skeleton.bin" then
                list[#list+1] = path
            end
        end
    end
    local animations = {}
    for _, path in ipairs(list) do
        local stemname = path:stem():string()
        local newname = stemname:gsub("[<>:/\\|?%s%[%]%(%)]", "_")
        if stemname ~= newname then
            local newpath = path:parent_path() / (newname .. path:extension())
            lfs.rename(path, newpath)
        end
        animations[newname] = newname .. path:extension():string()
    end
    status.animation.skeleton = "skeleton.bin"
    status.animation.animations = animations
end
