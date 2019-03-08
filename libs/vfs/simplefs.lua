local vfs = require "vfs"

local nio_open = io.open

local function join(dir, file)
    if file:sub(1, 1) == '/' then
        return file
    end
    return dir:gsub("(.-)/?$", "%1") .. '/' .. file
end

local function each(dir)
    local list = vfs.list(dir)
    local name
    return function()
        name = next(list, name)
        if not name then
            return
        end
        return name
    end
end


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
    local f, err, ec = nio_open(real_filename, mode)
    if not f then
        err = errmsg(err, filename, real_filename)
        return nil, err, ec
    end
    return f
end

local function loadfile(path, ...)
    local f, err = io_open(path, 'r')
    if not f then
        return nil, err
    end
    local str = f:read 'a'
    f:close()
    return load(str, '@/vfs/' .. path, ...)
end

local function dofile(path)
    local f, err = loadfile(path)
    if not f then
        error(err)
    end
    return f()
end

return {
    join = join,
    each = each,
    type = vfs.type,
    realpath = vfs.realpath,
    dofile = dofile,
}
 