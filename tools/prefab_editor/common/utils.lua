local utils = {}
local function do_deep_copy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[do_deep_copy(orig_key)] = do_deep_copy(orig_value)
        end
        setmetatable(copy, do_deep_copy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end
function utils.deep_copy(orig)
    return do_deep_copy(orig)
end

function utils.time2str(time)
    local fmt = "%Y-%m-%d %H:%M:%S:"
    local ti, tf = math.modf(time)
    return os.date(fmt, ti)..string.format("%03d",math.floor(tf*1000))
end

local fs = require "filesystem"
local lfs = require "filesystem.local"

function utils.write_file(filename, data)
    local f = assert(lfs.open(fs.path(filename):localpath(), "wb"))
    f:write(data)
    f:close()
end

local datalist  = require "datalist"
function utils.readtable(filename)
    local path = fs.path(filename):localpath()
    local f = assert(lfs.open(path))
	local data = f:read "a"
	f:close()
    return datalist.parse(data)
end

return utils