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
        linda:send("log", {"Script", "MSG_PROCESS",os.clock(), table.unpack(print_table)})
    end

    perror = function(...)
        origin_print("ERROR!!", "MSG_PROCESS",...)
        local error_table = {...}
        for k, v in ipairs(error_table) do
            error_table[k] = tostring(v)
        end
        linda:send("log", {"Error", table.unpack(error_table)})
    end

    local vfs = require "firmware.vfs"
    vfs_repo = vfs.new(_pkg_dir, _sb_dir .. "/Documents")
    --local file, hash = vfs_repo:open("/fw/msg_process.lua")

    ---[[
    origin_open = io.open
    io.open = function(filename, mode)
        while true do
           -- print("open file", filename)
            --[[
            local file, hash = vfs_repo:open(filename)
            if file then
                return file
            end
            --]]
            local file_path, hash
            linda:send("vfs_open", filename)
            while true do
                local _, value = linda:receive("vfs_open_res"..filename, 0.001)
                if value then
                    file_path, hash = value[1], value[2]
                    break
                end
            end

            if file_path then
                print("get file: "..filename)
                return origin_open(file_path, mode)
            end

            print("hash is: " ..tostring(hash))
            if not hash then
                print("file does not exist in repo: "..filename)
                break
            end

            print("Try to request hash from server", filename, hash)
            local request = {"EXIST", hash}
            linda:send("request", request)

            local realpath
            while not realpath do
                local _, value = linda:receive(0.001, "file exist")
                if value == "not exist" then
                    --not such file on server
                    print("error: file "..filename.." can't be found")
                    break
                else
                    realpath = value
                end
            end

            if not realpath then
                break
            end

            --value is the real path
            request = {"GET", realpath, hash}
            linda:send("request", request)
            -- get file
            while true do
                local _, file_value = linda:receive(0.001, "new file")
                if file_value then
                    --file_value should be local address
                    --client_repo:write should be called in io thread
                    print("get new file: " .. realpath)
                    break
                end
            end

        end

        return origin_open(filename, mode)
    end
--]]

    local function get_require_search_path(r_name)
        --return a table of possible path the file is on
        local search_string = package.path
        local search_table = {}

        --separate with ";"
        --"../" not support

        --print("require search string", search_string)
        for s_path in string.gmatch(search_string, ".-;") do
            --print("get requrie search path: "..s_path)

            local r_path = string.gsub(r_name, "%.", "/")
            s_path = string.gsub(s_path, "?", r_path)
            --get rid of ";" symbol
            s_path = string.gsub(s_path, ";", "")
            table.insert(search_table, s_path)
        end

        print("search path is:")
        for k, v in ipairs(search_table) do
            print(k, v)
        end

        return search_table
    end

    local require_cache = {}    --record every files that was required, use to clear package.loaded every "run"
    local function remote_searcher(name)
        ---search through package.remote_search_path
        local file_table = get_require_search_path(name)
        for _, v in ipairs(file_table) do
            local r_file = io.open(v, "rb")
            if r_file then
                print("open required file", name, v)
                io.input(r_file)
                local r_data = r_file:read("a")
                r_file:close()

                --cache the required file name
                table.insert(require_cache, name)
                return load(r_data)
            end
        end

        --required file not exist in the search path
        --print("require failed")
        local err_msg = ""
        for _, v in ipairs(file_table) do
            --print("can't find: "..name.." in " .. v)
            err_msg = err_msg .. "can't open: " .. name .. " in " .. v
        end

        --print("require error",err_msg)
        return nil, err_msg
    end
    table.insert(package.searchers, 1, remote_searcher)

    print("create msg processor (remote)")
    --local msg_process = require "fw.msg_process"
    local res, msg_process = xpcall(require, debug.traceback, "fw.msg_process")
    if not res then
        perror(msg_process)
        return
    end

    --local mp = msg_process.new(linda, pkg_dir, sb_dir, vfs_repo)
    local res, mp = xpcall(msg_process.new, debug.traceback, linda, pkg_dir, sb_dir)
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