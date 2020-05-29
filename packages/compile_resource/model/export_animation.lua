local fs = require "filesystem.local"
local utilitypkg = import_package "ant.utility"
local subprocess = utilitypkg.subprocess
local fs_local   = utilitypkg.fs_local

local util = require "model.util"

return function (input, output, exports)
    local anifolder = output / "animations"
    fs.create_directories(anifolder)
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
        tostring(fs_local.valid_tool_exe_path "gltf2ozz"),
        "--file=" .. (cwd / input):string(),
        stdout = true,
        stderr = true,
        hideWindow = true,
        cwd = anifolder:string(),
    }

    if success then
        local skefile = anifolder / "skeleton.ozz"
        if not fs.exists(skefile) then
            print("NO SKELETON export!")
        else
            exports.skeleton = util.subrespath(output, skefile)
        end

        exports.animations = fs_local.list_files(anifolder, ".ozz", {"skeleton.ozz"}, function (p)
            return util.subrespath(output, p)
        end)
    end
    print((success and "success" or "failed"), msg)
end
