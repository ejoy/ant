local socket = require 'bee.socket'

local listens = {}
local connects = {}
local wantconnects = {}
local event = {}
local rds = {}
local wds = {}
local read = setmetatable({}, {__index = function() return '' end})
local write = setmetatable({}, {__index = function() return '' end})
local willclose = {}
local shutdown = {}

local function open_read(fd)
    for _, r in ipairs(rds) do
        if r == fd then
            return
        end
    end
    rds[#rds+1] = fd
end

local function open_write(fd)
    for _, w in ipairs(wds) do
        if w == fd then
            return
        end
    end
    wds[#wds+1] = fd
end

local function close_read(fd)
    for i, f in ipairs(rds) do
        if f == fd then
            rds[i] = rds[#rds]
            rds[#rds] = nil
            return
        end
    end
end

local function close_write(fd)
    for i, f in ipairs(wds) do
        if f == fd then
            wds[i] = wds[#wds]
            wds[#wds] = nil
            return
        end
    end
end

local function close_listen(fd)
    for i, f in ipairs(listens) do
        if f == fd then
            listens[i] = listens[#listens]
            listens[#listens] = nil
            return
        end
    end
end

local function close_connect(fd)
    for i, f in ipairs(connects) do
        if f == fd then
            connects[i] = connects[#connects]
            connects[#connects] = nil
            return
        end
    end
end

local function close(fd)
    if event[fd] then event[fd]('close', fd) end
    close_listen(fd)
    close_connect(fd)
    close_read(fd)
    close_write(fd)
    fd:close()
    read[fd] = nil
    write[fd] = nil
    event[fd] = nil
    shutdown[fd] = true
    willclose[fd] = true
end

local function attach(fd)
    open_read(fd)
    if write[fd] ~= '' then
        open_write(fd)
    end
end

local m = {}

function m.recv(fd, n)
    if n and #read[fd] > n then
        local data = read[fd]:sub(1, n)
        read[fd] = read[fd]:sub(n+1)
        return data
    else
        local data = read[fd]
        read[fd] = ''
        return data
    end
end

function m.send(fd, data)
    if shutdown[fd] then
        return
    end
    if data == '' then
        return
    end
    write[fd] = write[fd] .. data
    open_write(fd)
end

function m.close(fd)
    willclose[fd] = true
    if shutdown[fd] or write[fd] == '' then
        close(fd)
    end
end

function m.is_closed(fd)
    return shutdown[fd] and willclose[fd]
end

function m.cleanup(fd)
    shutdown[fd] = nil
    willclose[fd] = nil
    read[fd] = nil
    write[fd] = nil
    event[fd] = nil
end

function m.listen(t)
    local fd, err = socket(t.protocol)
    if not fd then
        return nil, err
    end
    if t.protocol == "unix" then
        os.remove(t.address)
    end
    ok, err = fd:bind(t.address, t.port)
    if not ok then
        fd:close()
        return nil, err
    end
    ok, err = fd:listen()
    if not ok then
        fd:close()
        return nil, err
    end
    listens[#listens+1] = fd
    event[fd] = t.event
    return fd
end

function m.connect(t)
    local fd, err = socket(t.protocol)
    if not fd then
        return nil, err
    end
    ok, err = fd:connect(t.address, t.port)
    if ok == nil then
        fd:close()
        return nil, err
    end
    connects[#connects+1] = fd
    event[fd] = t.event
    return fd
end

function m.wantconnect(t)
    local i = 1
    while true do
        if not wantconnects[i] then
            wantconnects[i] = t
            return i
        end
        i = i + 1
    end
end

function m.dontwantconnect(idx)
    wantconnects[idx] = nil
end

local function updateLC()
    for idx, wc in pairs(wantconnects) do
        local fd = m.connect(wc)
        if fd then
            m.dontwantconnect(idx)
            event[fd]('connect start', fd)
            break
        end
    end
    if #listens == 0 and #connects == 0 then
        return
    end
    local rd, wr = socket.select(listens, connects, 0)
    if not rd then
        return
    end
    for _, fd in ipairs(rd) do
        local newfd = fd:accept()
        if newfd:status() then
            event[fd]('accept', newfd)
            if newfd:status() then
                event[newfd] = event[fd]
                attach(newfd)
            end
        end
    end
    for _, fd in ipairs(wr) do
        close_connect(fd)
        local ok, err = fd:status()
        if ok then
            event[fd]('ok', fd)
            attach(fd)
        else
            event[fd]('connect failed', fd, err)
            close(fd)
        end
    end
end

function m.update(timeout)
    updateLC()
    local rd, wr = socket.select(rds, wds, timeout)
    if not rd then
        return
    end
    for _, fd in ipairs(rd) do
        local data = fd:recv()
        if data == nil then
            close(fd)
        elseif data == false then
        else
            read[fd] = read[fd] .. data
        end
    end
    for _, fd in ipairs(wr) do
        local n = fd:send(write[fd])
        if n == nil then
            close_write(fd)
            shutdown[fd] = true
            if willclose[fd] then
                close(fd)
            end
        else
            write[fd] = write[fd]:sub(n + 1)
            if write[fd] == '' then
                close_write(fd)
                if willclose[fd] then
                    close(fd)
                end
            end
        end
    end
end

function m.closeall()
    for fd in pairs(write) do
        if not m.is_closed(fd) then
            m.close(fd)
        end
    end
    local function is_finish()
        for fd in pairs(write) do
            if not m.is_closed(fd) then
                return false
            end
        end
        return true
    end
    while not is_finish() do
        m.update(0)
    end
end

return m
