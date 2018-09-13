local log, fw_dir, remote_dir = ...
print("run framework dir", fw_dir, remote_dir, package.path)

local res, err = add_module("libs/fw/fw_io.lua", err_log, fw_dir, remote_dir)
if not res then
    error(err)
end

while true do
    local key, value = linda:receive(0.001, "new connection", "server_root_updated")
    if value then
        break
    end
end

res, err = add_module("libs/fw/fw_msgprocess.lua", err_log, fw_dir, remote_dir)
if not res then
    error(err)
end

res, err = add_module("libs/fw/fw_init.lua", err_log, fw_dir, remote_dir)
if not res then
    error(err)
end