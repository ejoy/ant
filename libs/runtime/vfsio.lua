local vfs = require 'vfs'

local nio = io

local function errmsg(err, filename, real_filename)
    local first, last = err:find(real_filename, 1, true)
    if not first then
        return err
    end
    return err:sub(1, first-1) .. filename .. err:sub(last+1)
end

local function io_open(filename, mode)
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

nio.dofile = dofile
nio.loadfile = loadfile

local function loadfile(path, mode, env)
    local f, err = io_open(path, 'r')
    if not f then
        return nil, err
    end
    local str = f:read 'a'
    f:close()
    return load(str, '@/vfs/' .. path, mode, env)
end

local function dofile(path)
    local f, err = loadfile(path)
    if not f then
        error(err)
    end
    return f()
end

io.dofile = dofile
io.loadfile = loadfile

_G.loadfile = loadfile
_G.dofile = dofile
