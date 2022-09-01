local lfs      = require "filesystem.local"
local datalist = require "datalist"

local m = {}

function m.add(t, v)
    if not t[v] then
        t[#t+1] = v
        t[v] = true
    end
end

function m.append(t, a)
    for _, v in ipairs(a) do
        if not t[v] then
            t[#t+1] = v
            t[v] = true
        end
    end
end

local function writefile(filename, data)
	local f = assert(lfs.open(filename, "wb"))
	f:write(data)
	f:close()
end

local function readfile(filename)
	local f = assert(lfs.open(filename))
	local data = f:read "a"
	f:close()
	return data
end

local function readconfig(filename)
    return datalist.parse(readfile(filename))
end

function m.writefile(filename, t)
    local w = {}
    for _, file in ipairs(t) do
        local path = lfs.path(file)
        if lfs.exists(path) then
            w[#w+1] = ("{%d, %q}"):format(lfs.last_write_time(path), lfs.absolute(path):string())
        else
            w[#w+1] = ("{0, %q}"):format(lfs.absolute(path):string())
        end
    end
    writefile(filename, table.concat(w, "\n"))
end

function m.dirty(path)
    if not lfs.exists(path) then
        return true
    end
    for _, dep in ipairs(readconfig(path)) do
        local timestamp, filename = dep[1], lfs.path(dep[2])
        if timestamp == 0 then
            if lfs.exists(filename) then
                return true
            end
        else
            if not lfs.exists(filename) or timestamp ~= lfs.last_write_time(filename) then
                return true
            end
        end
    end
end

return m
