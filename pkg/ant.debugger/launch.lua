local path = debug.getinfo(1,"S").source:sub(2)
    :match("(.+)[/\\][%w_.-]+$")
    :match("(.+)[/\\][%w_.-]+$")

local function dofile(filename, ...)
    local load = _VERSION == "Lua 5.1" and loadstring or load
    local f = assert(io.open(filename))
    local str = f:read "*a"
    f:close()
    return assert(load(str, "=(debugger.lua)"))(...)
end
local dbg = dofile(path.."/script/debugger.lua", path)
dbg:set_wait("DBG", function(str)
    local params = {}
    str:gsub('[^-]+', function (w) params[#params+1] = w end)

    local cfg
    if  not params[1]:match "^%d+$" then
        local client, address = params[1]:match "^([sc]):(.*)$"
        cfg = { address = address, client = (client == "c") }
    else
        local pid = params[1]
        cfg = { address = ("@%s/tmp/pid_%s"):format(path, pid) }
    end
    for i = 2, #params do
        local param = params[i]
        cfg[param] = true
    end
    dbg:start(cfg)
end)
