local ecs = ...
local filewatch_system = ecs.system "filewatch_system"

filewatch_system.singleton "vfs_update_component"
local fs = require "lfs"

local fw = require "filewatch"
function filewatch_system:init()
    --create file watch
    --FIXME: for now only watch "libs" directory
    --TODO: multiple directory watching
    local root_dir = fs.currentdir()
    print("init file watch system", root_dir)
    local path = require "filesystem.path"
    local watch = assert(fw.add(path.join(root_dir, "libs"), "fdts"))
    self.fw_watch = watch
    print("file watch system init complete")
end

function filewatch_system:update()
    while true do
        local id, type, filepath = fw.select()
        if id then
            local path = require "filesystem.path"
            filepath = path.normalize(filepath)
            local full_path = path.join("libs", filepath)

            print("fw catch", id, type, full_path)
            local vfsutil = require "vfs.util"
            vfsutil.clear_timestamp_cache(full_path)

            --self.localcache[full_path] = nil
            self.vfs_update_component.do_update = true
        else
            break
        end
    end
end
