--process messages
function CreateMsgProcessThread(_linda, _pkg_dir, _sb_dir)
    print("create msg process thread")

    linda = _linda
    pkg_dir = _pkg_dir
    sb_dir = _sb_dir

    local vfs = require "firmware.vfs"
    local vfs_repo = vfs.new(_pkg_dir, _sb_dir .. "/Documents")

    local origin_require = require
    require = function(require_path)
        print("requiring "..require_path)
        if io_repo then
            local file_path = string.gsub(require_path, "%.", "/")
            file_path = file_path .. ".lua"
            local file = vfs_repo:open(file_path)
            print("search for file path", file_path)
            if file then
                local content = file:read("a")
                print("content", content)
                file:close()

                local result, err_msg = load(content)
                if not result then
                    print("require " .. require_path .. " error: " .. err_msg)
                    return nil
                else
                    local status, return_res = xpcall(result, debug.traceback)
                    if status then
                        error(return_res)
                        return nil
                    else
                        return return_res
                    end
                end
            end
        end

        print("use origin require")
        return origin_require(require_path)
    end

    print("create msg processor")
    local msg_process = require "msg_process"
    local mp = msg_process.new(linda, pkg_dir, sb_dir, vfs_repo)

    print("update msg processor")
    while true do
        mp:mainloop()
    end
end

local lanes_err
msg_process_thread, lanes_err = lanes.gen("*", CreateMsgProcessThread)(linda, pkg_dir, sb_dir)
if not msg_process_thread then
    assert(false, "lanes error: " .. lanes_err)
end