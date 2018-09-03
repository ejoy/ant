local log, cfuncs, pkg_dir, sand_box_dir = ...

f_table = cfuncs()
f_table.preloadc()

RUN_FUNC = nil  --the function currently running"
RUN_FUNC_NAME = nil --the name of the running function"

package.path = "/libs/?.lua;/libs/?/?.lua;/libs/fw/?.lua;" .. pkg_dir .. "/fw/?.lua;" .. pkg_dir .. "/?.lua;"
local vfs = require "firmware.vfs"
client_repo = vfs.new(pkg_dir, sand_box_dir .. "/Documents")

ant_load = function(path, vfs_repo)
    --if pass vfs_repo, then use vfs_repo:open
    local file, err = nil, ""
    if vfs_repo then
        file = vfs_repo:open(path)
        if not file then
            err = path .. " not found"
            return nil, err
        end
    else
        --else, use io.open
        file, err = io.open(path, "rb")
        if not file then
            return nil, err
        end
    end

    --print("load file ~~ ".. path)
    local content = file:read("a")
    file:close()

    return load(content, "@" .. path)
end

local function add_module(path, ...)
    local res, err = ant_load(path, client_repo)
    if not res then
        error("load module " .. path .. " error: " .. err)
        return
    end

    print("add module: " .. path .. " finished")
    return xpcall(res, debug.traceback,...)
end


--TODO: find a way to set this
--path for the remote script
lanes = require "lanes"
if lanes.configure then lanes.configure({with_timers = false, on_state_create = custom_on_state_create}) end
linda = lanes.linda()


--io_module // io thread
local res, err = add_module("/libs/fw/fw_io.lua", log, pkg_dir, sand_box_dir)
if not res  then
    --assert(false, "io thread not valid: "..err)
    error(err)
end

--todo: offline mode?
while true do
    local key, value = linda:receive(0.001, "new connection")
    if value then
        break
    end
end

--msg process thread
res, err = add_module("/libs/fw/fw_msgprocess.lua", log, pkg_dir, sand_box_dir)
if not res then
    perror(err)
end

--init module // game thread
res, err = add_module("/libs/fw/fw_init.lua", log, pkg_dir, sand_box_dir)
if not res then
    perror(err)
end


