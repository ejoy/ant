local lfs       = require "bee.filesystem"
local fs        = require "filesystem"
local datalist  = require "datalist"
local fastio    = require "fastio"

local m = {}

local function get_write_time(path)
    if not lfs.exists(path) then
        return 0
    end
    return lfs.last_write_time(path)
end

function m.add(t, v)
    local abspath = lfs.absolute(v):lexically_normal():string()
    if not t[abspath] then
        t[#t+1] = abspath
        t[abspath] = get_write_time(abspath)
    end
end

function m.insert_front(t, v)
    local abspath = v
    if not t[abspath] then
        table.insert(t, 1, abspath)
        t[abspath] = get_write_time(abspath)
    end
end

function m.append(t, a)
    for _, v in ipairs(a) do
        if not t[v] then
            t[#t+1] = v
            t[v] = a[v]
        end
    end
end

local function writefile(filename, data)
	local f <close> = assert(io.open(filename:string(), "wb"))
	f:write(data)
end

local function readconfig(filename)
    return datalist.parse(fastio.readall(filename:string()))
end

function m.writefile(filename, t)
    local w = {}
    for _, path in ipairs(t) do
        w[#w+1] = ("{%d, %q}"):format(t[path], path)
    end
    writefile(filename, table.concat(w, "\n"))
end

function m.dirty(path)
    if not lfs.exists(path) then
        return true
    end
    for _, dep in ipairs(readconfig(path)) do
        local timestamp, filename = dep[1], dep[2]
        if timestamp == 0 then
            if lfs.exists(filename) then
                return filename
            end
        else
            if not lfs.exists(filename) or timestamp ~= lfs.last_write_time(filename) then
                return filename
            end
        end
    end
end

function m.read_if_not_dirty(path)
    if not lfs.exists(path) then
        return
    end
    local i = 0
    local deps = {}
    for _, dep in ipairs(readconfig(path)) do
        local timestamp, filename = dep[1], dep[2]
        if timestamp == 0 then
            if lfs.exists(filename) then
                return
            end
        else
            if not lfs.exists(filename) or timestamp ~= lfs.last_write_time(filename) then
                return
            end
        end
        i = i + 1
        deps[i] = filename
        deps[filename] = timestamp
    end
    return deps
end

return m
