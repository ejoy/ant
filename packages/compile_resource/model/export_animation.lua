local fs = require "filesystem.local"
local utilitypkg = import_package "ant.utility"
local subprocess = utilitypkg.subprocess
local fs_local   = utilitypkg.fs_local

return function (input, output)
    local animation_folder = output / "animation"
    fs.create_directories(animation_folder)
    local success, msg = subprocess.spawn_process {
        tostring(fs_local.valid_tool_exe_path "gltf2ozz"),
        "--file=" .. input:string(),
        stdout = true,
        stderr = true,
        hideWindow = true,
        cwd = animation_folder,
    }
    print((success and "success" or "failed"), msg)
end
