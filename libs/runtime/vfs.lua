local thread = require "thread"
local threadid = thread.id
local io_req = thread.channel "IOreq"
local io_resp = thread.channel ("IOresp" .. threadid)

local vfs = {}

local function npath(path)
	return path:match "^/?(.-)/?$"
end

function vfs.list(path)
	io_req:push("LIST", threadid, npath(path))
	return io_resp:bpop()
end

function vfs.realpath(path)
	io_req:push("GET", threadid, npath(path))
	return io_resp:bpop()
end

function vfs.prefetch(path)
	io_req:push("PREFETCH", npath(path))
end

package.loaded.vfs = vfs

local nio = io

local function errmsg(err, filename, real_filename)
    local first, last = err:find(real_filename, 1, true)
    if not first then
        return err
    end
    return err:sub(1, first-1) .. filename .. err:sub(last+1)
end

function io_open(filename, mode)
    if mode ~= nil and mode ~= 'r' and mode ~= 'rb' then
        return nil, ('%s:Permission denied.'):format(filename)
    end
    local real_filename = vfs.realpath(filename)
    if not real_filename then
        return nil, ('%s:No such file or directory.'):format(filename)
    end
    local f, err, ec = nio.open(real_filename, mode)
    if not f then
        err = errmsg(err, filename, real_filename)
        return nil, err, ec
    end
    return f
end

local io = {
    open = io_open,
    read = nio.read,
    write = nio.write,
    type = nio.type,
    flush = nio.flush,
    close = nio.close,
    popen = nio.popen,
    tmpfile = nio.tmpfile,
}

function io.input(filename)
    if type(filename) ~= 'string' then
        return nio.input(filename)
    end
    local real_filename = vfs.realpath(filename)
    if not real_filename then
        error(('%s:No such file or directory.'):format(filename))
    end
    local ok, res = pcall(nio.input, real_filename)
    if ok then
        return res
    end
    error(errmsg(res, filename, real_filename))
end

function io.output(filename)
    if type(filename) ~= 'string' then
        return nio.output(filename)
    end
    local real_filename = vfs.realpath(filename)
    if not real_filename then
        error(('%s:No such file or directory.'):format(filename))
    end
    local ok, res = pcall(nio.output, real_filename)
    if ok then
        return res
    end
    error(errmsg(res, filename, real_filename))
end

function io.lines(filename, ...)
    if type(filename) ~= 'string' then
        return nio.lines(filename, ...)
    end
    local real_filename = vfs.realpath(filename)
    if not real_filename then
        error(('%s:No such file or directory.'):format(filename))
    end
    local ok, res = pcall(nio.lines, real_filename, ...)
    if ok then
        return res
    end
    error(errmsg(res, filename, real_filename))
end

package.loaded.nativeio = nio
package.loaded.vfsio = io
package.loaded.io = io
_G.io = io

local function loadfile(path)
    local f, err = io_open(path, 'rb')
    if not f then
        return nil, err
    end
    local str = f:read 'a'
    f:close()
    return load(str, '@vfs://' .. path)
end

local function dofile(path)
    local f, err = io_open(path, 'rb')
    if not f then
        error(err)
    end
    return f()
end

_G.loadfile = loadfile
_G.dofile = dofile
