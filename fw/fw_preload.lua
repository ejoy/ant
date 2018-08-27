local log, cfuncs, pkg_dir, sand_box_dir = ...

f_table = cfuncs()
f_table.preloadc()

RUN_FUNC = nil  --the function currently running"
RUN_FUNC_NAME = nil --the name of the running function"

package.path = package.path .. ";" .. pkg_dir .. "/?.lua;"

local vfs = require "firmware.vfs"
client_repo = vfs.new(pkg_dir, sand_box_dir .. "/Documents")

local function add_module(path, ...)
    local module, hash = client_repo:open(path)

    if not module then
        assert(false, "cannot find module file: ".. path .." with hash " .. tostring(hash))
    end

    local module_content = module:read("a")
    module:close()

    local init_func = load(module_content, "@/fw/fw_init.lua")
    return init_func(...)
end

--io_module
if not add_module("/fw/fw_io.lua", log, pkg_dir, sand_box_dir) then
    assert(false, "io thread not valid")
end

--init module
if not add_module("/fw/fw_init.lua", log, pkg_dir, sand_box_dir) then

end


