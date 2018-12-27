local ls = require 'lsocket'

local listens = {}
local connects = {}
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
    close_listen(fd)
    close_connect(fd)
    close_read(fd)
    close_write(fd)
    fd:close()
    read[fd] = nil
    write[fd] = nil
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

function m.recv2(fd, n)
    if #read[fd] >= n then
        local data = read[fd]:sub(1, n)
        read[fd] = read[fd]:sub(n+1)
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

function m.listen(t)
    local fd, err = ls.bind(t.protocol, t.address, t.port)
    if not fd then
        return fd, err
    end
    listens[#listens+1] = fd
    event[fd] = t.event
    return fd
end

function m.connect(t)
    local fd, err = ls.connect(t.protocol, t.address, t.port)
    if not fd then
        return fd, err
    end
    connects[#connects+1] = fd
    event[fd] = t.event
    return fd
end

local function updateLC()
    if #listens == 0 and #connects == 0 then
        return
    end
    local rd, wr = ls.select(listens, connects, 0)
    if rd then
        for _, fd in ipairs(rd) do
            local newfd = fd:accept()
            if newfd:status() then
                if event[fd] then
                    event[fd]('accept', newfd)
                end
                attach(newfd)
            end
        end
    end
    if wr then
        for _, fd in ipairs(wr) do
            close_connect(fd)
            if fd:status() then
                if event[fd] then
                    event[fd]('ok', fd)
                end
                attach(fd)
            else
                if event[fd] then
                    event[fd]('failed', fd)
                end
                close(fd)
            end
        end
    end
end

function m.update(timeout)
    updateLC()
    local rd, wr = ls.select(rds, wds, timeout)
    if rd then
        for _, fd in ipairs(rd) do
            local data = fd:recv()
            if data == nil then
                close(fd)
            elseif data == false then
            else
                read[fd] = read[fd] .. data
            end
        end
    end
    if wr then
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
end

return m
