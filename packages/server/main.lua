local network = require "network"
local server = require "fileserver"
local proxy = require "mobiledevice.proxy"

local function init_server(cfg)
    server.init(cfg)
end

local function init_proxy()
    proxy.init()
end

local function listen(...)
    server.listen(...)
end

local function update_server()
    server.update()
end

local function update_proxy()
    proxy.update()
end

local fds = {}
local function update_network()
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
end

return {
    init_server = init_server,
    init_proxy = init_proxy,
    listen = listen,
    update_server = update_server,
    update_proxy = update_proxy,
    update_network = update_network,
    event = require "event",
}