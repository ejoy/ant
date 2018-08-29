--process messages
local log, pkg_dir, sb_dir = ...

function CreateMsgProcessThread(_linda, _pkg_dir, _sb_dir)
    linda = _linda
    pkg_dir = _pkg_dir
    sb_dir = _sb_dir

    origin_print = print
    print = function(...)
        origin_print(...)
        local print_table = {...}
        for k, v in ipairs(print_table) do
            print_table[k] = tostring(v)
        end
        linda:send("log", {"Script", os.clock(), table.unpack(print_table)})
    end

    perror = function(...)
        origin_print("ERROR!!", ...)
        local error_table = {...}
        for k, v in ipairs(error_table) do
            error_table[k] = tostring(v)
        end
        linda:send("log", {"Error", table.unpack(error_table)})
    end

    local vfs = require "firmware.vfs"
    local vfs_repo = vfs.new(_pkg_dir, _sb_dir .. "/Documents")

    local origin_require = require
    require = function(require_path)
        print("requiring "..require_path)
        if vfs_repo then
            local file_path = string.gsub(require_path, "%.", "/")
            file_path = file_path .. ".lua"
            local file = vfs_repo:open(file_path)
            print("search for file path", file_path)
            if file then
                local content = file:read("a")
                --print("content", content)
                file:close()

                local err, result = pcall(load, content, "@"..require_path)
                if not err then
                    print("require " .. require_path .. " error: " .. result)
                    return nil
                else
                    return result()
                end
            end
        end

        print("use origin require")
        return origin_require(require_path)
    end

    print("create msg processor 11")
    --local msg_process = require "fw.msg_process"
    local res, msg_process = xpcall(require, debug.traceback, "fw.msg_process")
    if not res then
        perror(msg_process)
        return
    end

    --local mp = msg_process.new(linda, pkg_dir, sb_dir, vfs_repo)
    local res, mp = xpcall(msg_process.new, debug.traceback, linda, pkg_dir, sb_dir, vfs_repo)
    if not res then
        perror(mp)
        return
    end

    print("update msg processor")
    while true do
        --mp:mainloop()
        local res, err = xpcall(mp.mainloop, debug.traceback, mp)
        if not res then
            perror(err)
            return
        end
    end
end

local lanes_err
msg_process_thread, lanes_err = lanes.gen("*", CreateMsgProcessThread)(linda, pkg_dir, sb_dir)
if not msg_process_thread then
    assert(false, "lanes error: " .. lanes_err)
end