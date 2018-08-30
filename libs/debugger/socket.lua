local lsocket = require 'lsocket'
local tremove = table.remove
local ipairs = ipairs
local sselect = lsocket.select

local r_cb = {}
local r_fd = {}
local w_cb = {}
local w_fd = {}
local w_buf = {}

local function read_init(fd, cb)
    r_cb[fd] = cb
end

local function read_open(fd)
    if not r_fd[fd] then
        r_fd[#r_fd + 1] = fd
        r_fd[fd] = #r_fd
    end
end

local function read_close(fd)
    if r_fd[fd] then
        tremove(r_fd, r_fd[fd])
        r_fd[fd] = nil
    end
end

local function write_init(fd, cb)
    w_cb[fd] = cb
end

local function write_open(fd)
    if not w_fd[fd] then
        w_fd[#w_fd + 1] = fd
        w_fd[fd] = #w_fd
    end
end

local function write_close(fd)
    if w_fd[fd] then
        tremove(w_fd, w_fd[fd])
        w_fd[fd] = nil
    end
end

local m = {}

function m.init(fd, rcb)
    read_init(fd, rcb)
    read_open(fd)
    write_init(fd, function()
        local n, e = fd:send(w_buf[fd])
        if n then
            w_buf[fd] = w_buf[fd]:sub(n + 1)
            if w_buf[fd] == '' then
                write_close(fd)
            end
        elseif n == nil then
            write_close(fd)
            --print('sockect error:' .. e)
        end
    end)
    w_buf[fd] = ''
end

function m.close(fd)
    read_close(fd)
    write_close(fd)
    r_cb[fd] = nil
    w_cb[fd] = nil
    w_buf[fd] = nil
end

function m.send(fd, data)
    if w_buf[fd] then
        w_buf[fd] = w_buf[fd] .. data
        write_open(fd)
    end
end

function m.update()
    local r, w = sselect(r_fd, w_fd, 0.05)
    if r then
        for _, fd in ipairs(r) do
            if r_fd[fd] then
                r_cb[fd]()
            end
        end
    end
    if w then
        for _, fd in ipairs(w) do
            if w_fd[fd] then
                w_cb[fd]()
            end
        end
    end
end

return m
