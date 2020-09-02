package.path = "engine/?.lua"
require "bootstrap"

local srv = import_package "ant.server"
local network = srv.network
local server = srv.server
local proxy = srv.proxy

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
