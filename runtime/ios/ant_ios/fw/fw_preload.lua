local log, cfuncs, pkg_dir, sand_box_dir = ...

f_table = cfuncs()
f_table.preloadc()

RUN_FUNC = nil  --the function currently running"
RUN_FUNC_NAME = nil --the name of the running function"

package.path = "/fw/?.lua;/libs/?.lua;/?.lua;./?/?.lua;/libs/?/?.lua;" .. pkg_dir .. "/fw/?.lua;" .. pkg_dir .. "/?.lua;"
local vfs = require "firmware.vfs"
client_repo = vfs.new(pkg_dir, sand_box_dir .. "/Documents")

local function add_module(path, ...)
    local module, hash = client_repo:open(path)

    if not module then
        assert(false, "cannot find module file: ".. path .." with hash " .. tostring(hash))
    end

    local module_content = module:read("a")
    module:close()

    local res, module_func = xpcall(load, debug.traceback, module_content, "@"..path)
    print("add module: " .. path)
    return xpcall(module_func, debug.traceback,...)
end


--TODO: find a way to set this
--path for the remote script
lanes = require "lanes"
if lanes.configure then lanes.configure({with_timers = false, on_state_create = custom_on_state_create}) end
linda = lanes.linda()


--io_module // io thread
local res, err = add_module("/fw/fw_io.lua", log, pkg_dir, sand_box_dir)
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
res, err = add_module("/fw/fw_msgprocess.lua", log, pkg_dir, sand_box_dir)
if not res then
    perror(err)
end

--init module // game thread
res, err = add_module("/fw/fw_init.lua", log, pkg_dir, sand_box_dir)
if not res then
    perror(err)
end


