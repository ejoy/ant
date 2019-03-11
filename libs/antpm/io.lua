local vfs = require "vfs.simplefs"

local nio = io

local function vfspath(value)
    local pm = require "antpm"
    assert(value:sub(1, 2) == '//')
    local pos = value:find('/', 3, true)
    if not pos then
        local root = pm.find(value:sub(3))
        if not root then
		    error(("No file '%s'"):format(value))
            return
        end
        return root
    end
	local root = pm.find(value:sub(3, pos-1))
	if not root then
        error(("No file '%s'"):format(value))
		return
	end
    return vfs.join(root, value:sub(pos+1))
end

local function localpath(path)
    return vfs.realpath(vfspath(path))
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
    local real_filename = localpath(filename)
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


local function io_lines(filename, ...)
    if type(filename) ~= 'string' then
        return nio.lines(filename, ...)
    end
    local real_filename = localpath(filename)
    if not real_filename then
        error(('%s:No such file or directory.'):format(filename))
    end
    local ok, res = pcall(nio.lines, real_filename, ...)
    if ok then
        return res
    end
    error(errmsg(res, filename, real_filename))
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
    open = io_open,
    lines = io_lines,
    dofile = dofile,
    loadfile = loadfile,
}
