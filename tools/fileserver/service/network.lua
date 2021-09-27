local ltask = require "ltask"
local exclusive = require "ltask.exclusive"
local socket = require "lsocket"

local kMaxReadBufSize <const> = 4 * 1024

local readfds = {}
local writefds = {}
local status = {}
local handle = {}

local function FD_SET(set, fd)
    for i = 1, #set do
        if fd == set[i] then
            return
        end
    end
    set[#set+1] = fd
end

local function FD_CLR(set, fd)
    for i = 1, #set do
        if fd == set[i] then
            set[i] = set[#set]
            set[#set] = nil
            return
        end
    end
end

local function fd_set_read(fd)
    FD_SET(readfds, fd)
end

local function fd_clr_read(fd)
    FD_CLR(readfds, fd)
end

local function fd_set_write(fd)
    FD_SET(writefds, fd)
end

local function fd_clr_write(fd)
    FD_CLR(writefds, fd)
end

local function create_handle(fd)
    local h = handle[fd]
    if h then
        return h
    end
    h = #handle + 1
    handle[h] = fd
    handle[fd] = h
    return h
end

local function close(s)
    local fd = s.fd
    fd:close()
    assert(s.shutdown_r)
    assert(s.shutdown_w)
    if s.wait_read then
        assert(#s.wait_read == 0)
    end
    if s.wait_write then
        assert(#s.wait_write == 0)
    end
    if s.wait_close then
        for _, token in ipairs(s.wait_close) do
            ltask.wakeup(token)
        end
    end
end

local function close_write(s)
    fd_clr_write(s.fd)
    if s.shutdown_r then
        fd_clr_read(s.fd)
        close(s)
    end
end

local function close_read(s)
    if not s.shutdown_r then
        s.shutdown_r = true
        fd_clr_read(s.fd)
        if s.wait_read then
            for i, token in ipairs(s.wait_read) do
                ltask.wakeup(token)
                s.wait_read[i] = nil
            end
        end
    end
end

local function stream_on_read(s)
    local data = s.fd:recv()
    if data == nil then
        close_read(s)
        if s.shutdown_w or #s.wait_write == 0 then
            s.shutdown_w = true
            fd_clr_write(s.fd)
            close(s)
        end
    elseif data == false then
    else
        s.readbuf = s.readbuf .. data

        while #s.wait_read > 0 do
            local token = s.wait_read[1]
            if not token then
                break
            end
            local n = token[1]
            if n == nil then
                ltask.wakeup(token, s.readbuf)
                s.readbuf = ""
                table.remove(s.wait_read, 1)
            else
                if n > #s.readbuf then
                    break
                end
                ltask.wakeup(token, s.readbuf:sub(1, n))
                s.readbuf = s.readbuf:sub(n+1)
                table.remove(s.wait_read, 1)
            end
        end

        if #s.readbuf > kMaxReadBufSize then
            fd_clr_read(s.fd)
        end
    end
end

local function stream_on_write(s)
    while #s.wait_write > 0 do
        local data = s.wait_write[1]
        local n = s.fd:send(data[1])
        if n == nil then
            for i, token in ipairs(s.wait_write) do
                ltask.interrupt(token, "Write close.")
                s.wait_write[i] = nil
            end
            s.shutdown_w = true
            close_write(s)
            return
        else
            if n == #data[1] then
                local token = table.remove(s.wait_write, 1)
                ltask.wakeup(token, n)
                if #s.wait_write == 0 then
                    close_write(s)
                    return
                end
            else
                data[1] = data[1]:sub(n + 1)
                return
            end
        end
    end
end

local S = {}

function S.bind(...)
    local fd = assert(socket.bind(...))
    status[fd] = {
        fd = fd,
        shutdown_r = false,
        shutdown_w = true,
    }
    return create_handle(fd)
end

function S.connect(...)
    local fd = assert(socket.connect(...))
    local s = {
        fd = fd,
        wait_write = {},
        shutdown_r = true,
        shutdown_w = false,
        on_write = ltask.wakeup,
    }
    status[fd] = s
    fd_set_write(fd)
    ltask.wait(s)
    local ok, err = fd:status()
    if ok then
        s.readbuf = ""
        s.wait_read = {}
        s.shutdown_r = false
        s.on_read = stream_on_read
        s.on_write = stream_on_write
        fd_set_read(s.fd)
        if #s.wait_write > 0 then
            s:on_write()
        else
            fd_clr_write(s.fd)
        end
        return create_handle(s.fd)
    else
        s.shutdown_w = true
        fd_clr_write(s.fd)
        close(s)
        return nil, err
    end
end

function S.listen(h)
    local fd = assert(handle[h], "Invalid fd.")
    local s = status[fd]
    s.on_read = ltask.wakeup
    fd_set_read(fd)
    ltask.wait(s)
    local newfd = fd:accept()
    if newfd:status() then
        status[newfd]  = {
            fd = newfd,
            readbuf = "",
            wait_read = {},
            wait_write = {},
            shutdown_r = false,
            shutdown_w = false,
            on_read = stream_on_read,
            on_write = stream_on_write,
        }
        fd_set_read(newfd)
        return create_handle(newfd)
    end
end

function S.send(h, data)
    local fd = assert(handle[h], "Invalid fd.")
    local s = status[fd]
    if not s.wait_write then
        error "Write not allowed."
        return
    end
    if s.shutdown_w then
        return
    end
    if data == "" then
        return 0
    end
    if #s.wait_write == 0 then
        fd_set_write(fd)
    end

    local token = {
        data,
    }
    s.wait_write[#s.wait_write+1] = token
    return ltask.wait(token)
end

function S.recv(h, n)
    local fd = assert(handle[h], "Invalid fd.")
    local s = status[fd]
    if not s.readbuf then
        error "Read not allowed."
        return
    end
    if s.shutdown_r then
        if not n then
            if s.readbuf == "" then
                return
            end
        else
            if n > kMaxReadBufSize then
                n = kMaxReadBufSize
            end
            if n > #s.readbuf then
                return
            end
        end
    end
    local sz = #s.readbuf
    if not n then
        if sz == 0 then
            local token = {
            }
            s.wait_read[#s.wait_read+1] = token
            return ltask.wait(token)
        end
        local ret = s.readbuf
        if sz > kMaxReadBufSize then
            fd_set_read(s.fd)
        end
        s.readbuf = ""
        return ret
    else
        if n > kMaxReadBufSize then
            n = kMaxReadBufSize
        end
        if n <= sz then
            local ret = s.readbuf:sub(1, n)
            if sz > kMaxReadBufSize and sz - n <= kMaxReadBufSize then
                fd_set_read(s.fd)
            end
            s.readbuf = s.readbuf:sub(n+1)
            return ret
        else
            local token = {
                n,
            }
            s.wait_read[#s.wait_read+1] = token
            return ltask.wait(token)
        end
    end
end

function S.close(h)
    local fd = handle[h]
    if fd then
        local s = status[fd]
        close_read(s)
        if s.shutdown_w or not s.wait_write or #s.wait_write == 0 then
            s.shutdown_w = true
            fd_clr_write(fd)
            close(s)
        else
            local token = {}
            if s.wait_close then
                s.wait_close[#s.wait_close+1] = token
            else
                s.wait_close = {token}
            end
            ltask.wait(token)
        end
        handle[h] = nil
        handle[fd] = nil
        status[fd] = nil
    end
end

ltask.fork(function()
    while true do
        local rd, wr = socket.select(readfds, writefds, 0.001)
        if rd then
            for i = 1, #rd do
                local fd = rd[i]
                local s = status[fd]
                s:on_read()
            end
            for i = 1, #wr do
                local fd = wr[i]
                local s = status[fd]
                s:on_write()
            end
        end
        ltask.sleep(0)
    end
end)

function S.quit()
end

return S
