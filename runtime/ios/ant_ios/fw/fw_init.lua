---used for initialize structure
local log, pkg_dir, sand_box_dir = ...
function safe_run(func, name,...)
    local res, run_data = xpcall(func, debug.traceback, ...)
    if not res then
        perror("run func " .. name .. " error: " .. run_data)
    end

    return res, run_data
end

winfile = require "winfile"
lodepng = require "lodepnglua"

g_WindowHandle = nil
g_Width, g_Height = 0

origin_open = io.open
io.open = function (filename, mode, search_local_only)
    --default we don't search local only
    search_local_only = search_local_only or false

    --vfs not initialized, can only use origin function

    print("start open file ", filename)

    if client_repo or io_thread then
        print("opening file: " .. filename)
        while true do
            --have io thread
            local hash
            if io_thread then
                local file_path
                linda:send("vfs_open", filename)
                while true do
                    local _, value = linda:receive("vfs_open_res", 0.001)
                    if value then
                        file_path, hash = value[1], value[2]
                        break
                    end
                end

                if file_path then
                    print("get file: "..filename)
                    return origin_open(file_path, mode)
                end
            else
                --don't have io initiated, use local repo(currently only use to open file for io)
                local file
                file, hash = client_repo:open(filename)
                if file then
                    --io not init, but have local repo
                    print("get file: "..filename)
                    return file
                end
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

    end
    --[[
        print("origin find file: " ..filename)
        local file, error = origin_open(filename, mode)
        if not file then
            print("cannot open file : "..filename)
        end
        return file, error
        --]]
    return origin_open(filename, mode)
end

local function get_require_search_path(r_name)
    --return a table of possible path the file is on
    local search_string = package.path
    local search_table = {}

    --separate with ";"
    --"../" not support

    print("require search string", search_string)
    for s_path in string.gmatch(search_string, ".-;") do
        print("get requrie search path: "..s_path)

        local r_path = string.gsub(r_name, "%.", "/")
        s_path = string.gsub(s_path, "?", r_path)
        --get rid of ";" symbol
        s_path = string.gsub(s_path, ";", "")
        table.insert(search_table, s_path)
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
            return load(r_data, "@"..v)
        end
    end

    --required file not exist in the search path
    --print("require failed")
    local err_msg = ""
    for _, v in ipairs(file_table) do
        --print("can't find: "..name.." in " .. v)
        err_msg = err_msg .. "can't open: " .. name " in " .. v
    end
    return nil, err_msg
end
table.insert(package.searchers, remote_searcher)

function run(path)
    print("run file: "..path)
    --clear the require "cache"
    for _, r_n in ipairs(require_cache) do
        package.loaded[r_n] = nil
    end

    package.loaded["fw.fw_connected"] = nil

    safe_run(require, "require", "fw.fw_connected")
    require_cache = {}

    if entrance then
        entrance.terminate()
        entrance = nil
    end

    local file = io.open(path, "rb")
    print("open file: "..path)
    io.input(file)
    local entrance_string = file:read("a")
    --print("entrance string: ", entrance_string)
    file:close()

    local res
    res, entrance = safe_run(load,"load", entrance_string, "@"..path)

    print("entracne is " ..tostring(entrance))
    --entrance should be a function
    if res then
        --load give a function, needs to run it
        res, entrance = safe_run(entrance, "entrance()")
        if res then
            --entrance.init(g_WindowHandle, g_Width, g_Height)
            local res = safe_run(entrance.init, "entrance.init",g_WindowHandle, g_Width, g_Height)
            if not res then
                entrance = nil
            end
        else
            entrance = nil
        end
    else
        entrance = nil
    end
end

--test RegisterIOCommand
local function dbg_test(value)
    print("XYZXYZ dbg_test_client: " .. tostring(value[1]) .. " and " ..  tostring(value[2]))
end

RegisterIOCommand("DBG_SERVER_SENT", dbg_test)

--todo: offline mode?
while true do
    local key, value = linda:receive(0.001, "new connection")
    if value then
        connect_to_server = true
        break
    end
end

--send last error to server
local err_file_path = sand_box_dir .. "/Documents/err.txt"
print("search for err file: "..err_file_path, origin_open)
local last_error = origin_open(err_file_path, "r")
print("00000")
if last_error then
    print("11111")
    local error_content = last_error:read("a")
    last_error:close()
    print("22222")
    local last_error_cover = origin_open(err_file_path, "w")
    --last_error_cover:write("hehe")
    if last_error_cover then last_error_cover:close() end
    print("33333")
    if #error_content > 0 then
        perror("last err: \n" .. error_content)
    end
    print("444444")
else
    --create one
    print("55555")
    local last_error_cover = origin_open(err_file_path, "w")
    if last_error_cover then last_error_cover:close() print("create file " .. err_file_path) end
end

--safe_run(require, "require", "fw.fw_connected")
require "fw.fw_connected"
print("123123123")
print(pcall(require, "fw.fw_connected"))
--SendIORequest({"DBG_CLIENT_SENT", "12345"})