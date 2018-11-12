local searcher_preload = package.searchers[1]
local searcher_C = ...
package.searchers[1] = searcher_preload
package.searchers[2] = searcher_C
package.searchers[3] = nil
package.loadlib = nil

package.path = "engine/libs/?.lua;engine/libs/?/?.lua"
local thread = require "thread"
local threadid = thread.id
-- main thread id is 0
if threadid ~= 0 then
    thread.newchannel ("IOresp" .. threadid)
end
local io_req = thread.channel "IOreq"
local io_resp = thread.channel ("IOresp" .. threadid)

local function fs_getpath(path)
	io_req:push("GET", threadid, path)
	return io_resp:bpop()
end

local function fs_has(path)
    local realpath = fs_getpath(path)
    if not realpath then
        return false
    end
    local f = io.open(realpath, 'rb')
    if not f then
        return false
    end
    f:close()
    return true
end

local function fs_loadfile(path)
    local realpath = fs_getpath(path)
    if not realpath then
        return nil, ('%s:No such file or directory'):format(path)
    end
    local f, err = io.open(realpath, 'rb')
    if not f then
        return nil, err
    end
    local str = f:read 'a'
    f:close()
    return load(str, '@vfs://' .. path)
end

local config = {}
package.config:gsub('[^\n]+', function (w) config[#config+1] = w end)

local LUA_DIRSEP    = config[1] -- '/'
local LUA_PATH_SEP  = config[2] -- ';'
local LUA_PATH_MARK = config[3] -- '?'
local LUA_EXEC_DIR  = config[4] -- '!'
local LUA_IGMARK    = config[5] -- '-'

local function searchpath(name, path)
    local err = ''
    name = string.gsub(name, '%.', '/')
    for c in string.gmatch(path, '[^;]+') do
        local filename = string.gsub(c, '%?', name)
        if fs_has(filename) then
            return filename
        end
        err = err .. ("\n\tno file '%s'"):format(filename)
    end
    return nil, err
end

local function searcher_Lua(name)
    assert(type(package.path) == "string", "'package.path' must be a string")
    local filename, err = searchpath(name, package.path)
    if not filename then
        return err
    end
    local f, err = fs_loadfile(filename)
    if not f then
        error(("error loading module '%s' from file '%s':\n\t%s"):format(name, filename, err))
    end
    return f, filename
end

package.searchers[1] = searcher_preload
package.searchers[2] = searcher_Lua
package.searchers[3] = searcher_C
package.searchers[4] = nil
package.searchpath = searchpath

loadfile = fs_loadfile
dofile = nil -- TODO
