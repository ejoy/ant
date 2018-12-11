package.cpath = package.cpath:gsub("%.so", ".dll")

local ls = require 'lsocket'
local md = require 'mobiledevice'
local thread = require 'thread'

local function LOG(...)
    print('[iOS proxy]', ...)
end

local clients = {}
local fds = {}

local function connect_server()
	local fd, err = ls.connect('127.0.0.1', 2018)
	if not fd then
		LOG("connect:", err)
		return
	end
	local rd, wt = ls.select(nil, {fd})
	if not rd then
		LOG("select:", wt)
		fd:close()
		return
	end
	local ok, err = fd:status()
	if not ok then
		fd:close()
		LOG("status:", err)
		return
	end
	LOG("Connected")
	return fd
end

local function update_proxy(client)
    if not client.ios_conn then
        return
    end
    if not client.srv_conn then
        client.srv_conn = connect_server()
        client.srv_queue = ''
        client.ios_queue = ''
    end
    if not client.srv_conn then
        return
    end

    local rd, wr = ls.select({client.srv_conn}, {client.srv_conn}, 0.01)
    if rd[1] then
        while true do
            local data, err = client.srv_conn:recv()
            if data == false then
                break
            end
            if data == nil then
                if err then
                    LOG("recv:", err)
                end
                return true
            end
            client.ios_queue = client.ios_queue .. data
        end
    end

    local data, err = client.ios_conn:recv()
    if not data then
        if err then
            LOG("recv:", err)
        end
        return true
    end
    client.srv_queue = client.srv_queue .. data

    if wr[1] then
        local n, err = client.srv_conn:send(client.srv_queue)
        if not n then
            LOG("send:", err)
            return true
        end
        client.srv_queue = client.srv_queue:sub(n+1)
    end

    local n, err = client.ios_conn:send(client.ios_queue)
    if not n then
        LOG("send:", err)
        return true
    end
    client.ios_queue = client.ios_queue:sub(n+1)
end

local function clients_init()
    for _, udid in ipairs(md.list()) do
        clients[udid] = clients[udid] or { STATUS = 'idle' }
        LOG('device init', udid)
    end
end

local function clients_update()
    while true do
        local type, udid = md.select()
        if not type then
            break
        end
        if type == 'add' then
            LOG('device add', udid)
            clients[udid] = clients[udid] or { STATUS = 'idle' }
        elseif type == 'remove' then
            LOG('device remove', udid)
            if clients[udid] then
                clients[udid].STATUS = { STATUS = 'wait_close' }
            end
        end
    end
end

local function clients_test()
    for udid, client in pairs(clients) do
        if client.STATUS == 'idle' then
            local conn, err = md.connect(udid, 2018)
            if conn then
                LOG('device ready', udid)
                client.STATUS = 'connected'
                client.ios_conn = conn
                client.update = update_proxy
            end
        end
    end
end

local function clients_proxy()
    for udid, client in pairs(clients) do
        if client.STATUS == 'connected' or client.STATUS == 'wait_close' then
            if update_proxy(client) then
                client.ios_conn:close()
                client.srv_conn:close()
                clients[udid] = { STATUS = 'idle' }
            end
        end
    end
end

clients_init()

while true do
    clients_update()
    clients_test()
    clients_proxy()
    thread.sleep(0)
end
