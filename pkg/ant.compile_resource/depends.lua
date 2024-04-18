local lfs       = require "bee.filesystem"
local datalist  = require "datalist"
local fastio    = require "fastio"

local m = {}

function m.new()
    return {
        vpath = {},
        lpath = {},
    }
end

local function get_write_time(path)
    if not lfs.exists(path) then
        return 1
    end
    return lfs.last_write_time(path)
end

function m.add_lpath(t, lpath)
    local abspath = lfs.absolute(lpath):lexically_normal():string()
    if not t.lpath[abspath] then
        t[#t+1] = {abspath, get_write_time(abspath)}
        t.lpath[abspath] = true
    end
end

function m.add_vpath(t, setting, vpath)
    local lpath = setting.vfs.realpath(vpath)
    if lpath then
        m.add_lpath(t, lpath)
        return
    end
    if not t.vpath[vpath] then
        t[#t+1] = {vpath, 0}
        t.vpath[vpath] = true
    end
end

function m.append(t, a)
    for _, v in ipairs(a) do
        if not t[v] then
            t[#t+1] = v
            t.lpath[v] = a.lpath[v]
            t.vpath[v] = a.vpath[v]
        end
    end
end

local function writefile(filename, data)
	local f <close> = assert(io.open(filename:string(), "wb"))
	f:write(data)
end

local function readconfig(filename)
    return datalist.parse(fastio.readall_f(filename:string()))
end

function m.writefile(filename, t)
    local w = {}
    for _, v in ipairs(t) do
        w[#w+1] = ("{%d, %q}"):format(v[2], v[1])
    end
    writefile(filename, table.concat(w, "\n"))
end

function m.dirty(setting, path)
    if not lfs.exists(path) then
        return true
    end
    for _, dep in ipairs(readconfig(path)) do
        local timestamp, filename = dep[1], dep[2]
        if timestamp == 0 then
            local rp = setting.vfs.realpath(filename)
            if rp then
                return rp
            end
        elseif timestamp == 1 then
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

function m.read_if_not_dirty(setting, path)
    local i = 0
    local deps = m.new()
    for _, dep in ipairs(readconfig(path)) do
        local timestamp, filename = dep[1], dep[2]
        if timestamp == 0 then
            local rp = setting.vfs.realpath(filename)
            if rp then
                return nil, rp
            end
        elseif timestamp == 1 then
            if lfs.exists(filename) then
                return nil, filename
            end
        else
            if not lfs.exists(filename) or timestamp ~= lfs.last_write_time(filename) then
                return nil, filename
            end
        end
        i = i + 1
        deps[i] = { filename, timestamp }
        if timestamp == 0 then
            deps.vpath[filename] = true
        else
            deps.lpath[filename] = true
        end
    end
    return deps
end

return m
