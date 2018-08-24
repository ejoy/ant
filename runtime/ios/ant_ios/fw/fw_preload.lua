local log, cfuncs, pkg_dir, sand_box_dir = ...

f_table = cfuncs()
f_table.preloadc()

RUN_FUNC = nil  --the function currently running"
RUN_FUNC_NAME = nil --the name of the running function"

package.path = package.path .. ";" .. pkg_dir .. "/?.lua;"

local vfs = require "firmware.vfs"
client_repo = vfs.new(pkg_dir, sand_box_dir .. "/Documents")

local init_f, hash = client_repo:open("/fw/fw_init.lua")

if not init_f then
    assert(false, "cannot find init file"..tostring(hash))
end

local init_content = init_f:read("a")
init_f:close()

local init_func = load(init_content, "@/fw/fw_init.lua")
init_func(log, pkg_dir, sand_box_dir)