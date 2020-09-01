package.path = "engine/?.lua;tools/fileserver/?.lua"
require "bootstrap"

local network = require "network"
local server = require "fileserver"
local proxy = require "mobiledevice.proxy"

local function luaexe()
    local i = -1
    while arg[i] ~= nil do i = i - 1 end
    return arg[i + 1]
end

server.init {
    lua = luaexe(),
    default_repo = arg[1]
}

server.listen("0.0.0.0", 2018)
proxy.init()

local fds = {}
while true do
    if network.dispatch(fds, 0.1) then
        for k, fd in ipairs(fds) do
            fds[k] = nil
            if not fd.update then
                assert(fd._ref)
                fd.update = fd._ref.update
            end
            fd:update()
        end
    end
    server.update()
    proxy.update()
end
