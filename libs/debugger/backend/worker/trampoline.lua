local cdebug = require 'debugger.backend'
local json = require 'cjson'
local pipe = cdebug.start 'vip'

local function loadfile(filename)
    pipe:send(assert(json.encode({
        cmd = 'loadfile',
        filename = filename,
    })))
    while true do
        local msg = pipe:recv()
        if not msg then
            cdebug.sleep(10)
        else
            local pkg = assert(json.decode(msg))
            assert(pkg.cmd == 'loadfile')
            if pkg.success then
                return pkg.result
            else
                return nil, pkg.message
            end
        end
    end
end

local function searchpath(name, path)
    local err = ''
    name = string.gsub(name, '%.', '/')
    for c in string.gmatch(path, '[^;]+') do
        local filename = string.gsub(c, '%?', name)
        local buf = loadfile(filename)
        if buf then
            return filename, buf
        end
        err = err .. ("\n\tno file '%s'"):format(filename)
    end
    return nil, err
end

local function searcher_Lua(name)
    assert(type(package.path) == "string", "'package.path' must be a string")
    local filename, buf = searchpath(name, package.path)
    if not filename then
        return buf
    end
    -- TODO 正确的符号
    local f, err = load(buf)
    if not f then
        error(("error loading module '%s' from file '%s':\n\t%s"):format(name, filename, err))
    end
    return f, filename
end

local searcher_C = ...
if searcher_C then
    package.searchers = {
        searcher_Lua,
        searcher_C,
    }
else
    package.searchers = {
        searcher_Lua,
        package.searchers[3],
        package.searchers[4],
    }
end

require 'debugger.backend.worker'
