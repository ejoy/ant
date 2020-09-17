local network = require "network"
local server = require "fileserver"
local proxy = require "mobiledevice.proxy"

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
    init_server = server.init,
    init_proxy = proxy.init,
    listen = server.listen,
    update_server = server.update,
    update_proxy = proxy.update,
    update_network = update_network,
    set_repopath = server.set_repopath,
    console = server.console,
    event = require "event",
}
