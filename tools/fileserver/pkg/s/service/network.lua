local ltask = require "ltask"
local socket = require "bee.socket"
local epoll = require "bee.epoll"

local epfd = epoll.create(512)

local EPOLLIN <const> = epoll.EPOLLIN
local EPOLLOUT <const> = epoll.EPOLLOUT
local EPOLLERR <const> = epoll.EPOLLERR
local EPOLLHUP <const> = epoll.EPOLLHUP

local kMaxReadBufSize <const> = 4 * 1024

local status = {}
local handle = {}

local function fd_update(s)
    local flags = 0
    if s.r then
        flags = flags | EPOLLIN
    end
    if s.w then
        flags = flags | EPOLLOUT
    end
    if flags ~= s.event_flags then
        epfd:event_mod(s.fd, flags)
        s.event_flags = flags
    end
end

local function fd_set_read(s)
    s.r = true
    fd_update(s)
end

local function fd_clr_read(s)
    s.r = nil
    fd_update(s)
end

local function fd_set_write(s)
    s.w = true
    fd_update(s)
end

local function fd_clr_write(s)
    s.w = nil
    fd_update(s)
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
    epfd:event_del(fd)
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
    fd_clr_write(s)
    if s.shutdown_r then
        fd_clr_read(s)
        s.shutdown_w = true
        close(s)
    end
end

local function close_read(s)
    if not s.shutdown_r then
        s.shutdown_r = true
        fd_clr_read(s)
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
            fd_clr_write(s)
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
            fd_clr_read(s)
        end
    end
end

local function stream_on_write(s)
    while #s.wait_write > 0 do
        local data = s.wait_write[1]
        local n = s.fd:send(data[1])
        if n == nil then
            for i, token in ipairs(s.wait_write) do
                ltask.wakeup(token)
                s.wait_write[i] = nil
            end
            s.shutdown_w = true
            close_write(s)
            return
        elseif n == false then
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

function S.bind(protocol, ...)
    local fd = assert(socket.create(protocol))
    local ok, err = fd:bind(...)
    if not ok then
        return ok, err
    end
    assert(fd:listen())
    status[fd] = {
        fd = fd,
        shutdown_r = false,
        shutdown_w = true,
    }
    epfd:event_add(fd, 0)
    return create_handle(fd)
end

function S.connect(protocol, ...)
    local fd = assert(socket.create(protocol))
    local r, err = fd:connect(...)
    if r == nil then
        return r, err
    end
    local s = {
        fd = fd,
        wait_write = {},
        shutdown_r = true,
        shutdown_w = false,
        on_write = ltask.wakeup,
        w = true,
    }
    epfd:event_add(fd, EPOLLOUT)
    status[fd] = s
    ltask.wait(s)
    local ok, err = fd:status()
    if ok then
        s.readbuf = ""
        s.wait_read = {}
        s.shutdown_r = false
        s.on_read = stream_on_read
        s.on_write = stream_on_write
        fd_set_read(s)
        if #s.wait_write > 0 then
            s:on_write()
        else
            fd_clr_write(s)
        end
        return create_handle(s.fd)
    else
        s.shutdown_w = true
        fd_clr_write(s)
        close(s)
        return nil, err
    end
end

function S.listen(h)
    local fd = assert(handle[h], "Invalid fd.")
    local s = status[fd]
    s.on_read = ltask.wakeup
    fd_set_read(s)
    ltask.wait(s)
    local newfd, err = fd:accept()
    if not newfd then
        return nil, err
    end
    local ok, err = newfd:status()
    if not ok then
        return nil, err
    end
    status[newfd]  = {
        fd = newfd,
        readbuf = "",
        wait_read = {},
        wait_write = {},
        shutdown_r = false,
        shutdown_w = false,
        on_read = stream_on_read,
        on_write = stream_on_write,
        r = true,
    }
    epfd:event_add(newfd, EPOLLIN)
    return create_handle(newfd)
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
        fd_set_write(s)
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
            fd_set_read(s)
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
                fd_set_read(s)
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
            fd_clr_write(s)
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

do
    local waitfunc, fd = ltask.eventinit()
    local ltaskfd = socket.fd(fd)
    status[ltaskfd] = {
        on_read = waitfunc
    }
    epfd:event_add(ltaskfd, EPOLLIN)
end

ltask.idle_handler(function()
    for fd, event in epfd:wait() do
        if event & (EPOLLERR | EPOLLHUP) ~= 0 then
            event = event & (EPOLLIN | EPOLLOUT)
        end
        if event & EPOLLIN ~= 0 then
            local s = status[fd]
            s:on_read()
        end
        if event & EPOLLOUT ~= 0 then
            local s = status[fd]
            s:on_write()
        end
    end
end)

return S
