-- Step 1. init c searcher
local searcher_preload = package.searchers[1]
local searcher_C = package.searchers[3]

package.searchers[1] = searcher_preload
package.searchers[2] = searcher_C
package.searchers[3] = nil
package.loadlib = nil

-- Step 2. init vfs
local thread = require "thread"
local threadid = thread.id
-- main thread id is 0
if threadid ~= 0 then
    thread.newchannel ("IOresp" .. threadid)
end
local io_req = thread.channel "IOreq"
local io_resp = thread.channel ("IOresp" .. threadid)

local function npath(path)
	return path:match "^/?(.-)/?$"
end

local function vfs_list(path)
	io_req:push("LIST", threadid, npath(path))
	return io_resp:bpop()
end

local function vfs_realpath(path)
	io_req:push("GET", threadid, npath(path))
	return io_resp:bpop()
end

local function path_split(path)
    local t = {}
    path:gsub('[^/\\]*', function (w) t[#t+1] = w end)
    local filename = t[#t]
    t[#t] = nil
    return table.concat(t, '/'), filename
end

local function vfs_exists(path)
    local dir, filename = path_split(path)
    local list = vfs_list(dir)
    return list ~= nil and list[filename] ~= nil
end

-- Step 3. init dofile and loadfile
local io_open = io.open

local function errmsg(err, filename, real_filename)
    local first, last = err:find(real_filename, 1, true)
    if not first then
        return err
    end
    return err:sub(1, first-1) .. filename .. err:sub(last+1)
end

local function openfile(filename)
    local real_filename = vfs_realpath(filename)
    if not real_filename then
        return nil, ('%s:No such file or directory.'):format(filename)
    end
    local f, err, ec = io_open(real_filename, 'rb')
    if not f then
        err = errmsg(err, filename, real_filename)
        return nil, err, ec
    end
    return f
end

local function loadfile(path)
    local f, err = openfile(path)
    if not f then
        return nil, err
    end
    local str = f:read 'a'
    f:close()
    return load(str, '@vfs://' .. path)
end

-- Step 4. init lua searcher
package.path = "?.lua"

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
        if vfs_exists(filename) then
            return filename
        end
        err = err .. ("\n\tno file '%s'"):format(filename)
    end
    return nil, err
end

local function searcher_Lua(name)
    assert(type(package.path) == "string", "'package.path' must be a string")
    local filename, file = searchpath(name, package.path)
    if not filename then
        return file -- err
    end
    local func, err = loadfile(filename)
    if not func then
        error(("error loading module '%s' from file '%s':\n\t%s"):format(name, filename, err))
    end
    return func, filename
end

package.searchers[1] = searcher_preload
package.searchers[2] = searcher_Lua
package.searchers[3] = searcher_C
package.searchers[4] = nil
package.searchpath = searchpath

return openfile
