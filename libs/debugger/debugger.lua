local rdebug = require 'remotedebug'

local function loadfile(filename)
    local f, err = io.open(filename, 'rb')
    if not f then
        return nil, err
    end
    local str = f:read 'a'
    f:close()
    return str
end

local function searchpath(name, path)
    local err = ''
    name = string.gsub(name, '%.', '/')
    for c in string.gmatch(path, '[^;]+') do
        local filename = string.gsub(c, '%?', name)
        local buf, err = loadfile(filename)
        if buf then
            return filename, buf
        end
        err = err .. ("\n\tno file '%s'"):format(filename)
    end
    return nil, err
end

local function load_worker_entry(name)
    local filename, buf = searchpath(name, package.path)
    if not filename then
        error(("module '%s' not found:%s"):format(name, buf))
    end
    return buf
end

local function event(name, level, ...)
    local r
    rdebug.probe(name)
    return r
end

local function start_hook()
    local _print = print
    function print(...)
        if not event('print', 1, ...) then
            _print(...)
        end
    end

    local _xpcall = xpcall
    function xpcall(f, msgh, ...)
        return _xpcall(f, function(msg)
            event('exception', 2, 'xpcall', msg)
            return msgh(msg)
        end, ...)
    end

    local _pcall = pcall
    function pcall(f, ...)
        return _xpcall(f, function(msg)
            event('exception', 2, 'pcall', msg)
            return msg
        end, ...)
    end
    
    local _coroutine_resume = coroutine.resume
    function coroutine.resume(co, ...)
        event('coroutine', 1, co)
        return _coroutine_resume(co, ...)
    end
end

local function start_master(io)
    local master = require 'debugger.backend.master'
    if master.init(io) then
        return master.update
    end
end

local function start_worker(wait)
    start_hook()
    local entry = 'debugger.backend.worker.trampoline'
    local searcher_C = package.searcher_C or package.searchers[3]
    if debug.getupvalue(searcher_C, 1) then
        rdebug.start(load_worker_entry(entry))
    else
        rdebug.start(searcher_C, load_worker_entry(entry))
    end
    if wait then
        event('wait_client', 1, false)
    end
    return function()
        event 'update'
    end
end

local function start_all(wait)
    start_hook()
    rdebug.start('require "debugger.backend.worker"')
    if wait then
        event('wait_client', 1, true)
    end
    return function()
        event 'update_all'
    end
end

return {
    start_master = start_master,
    start_worker = start_worker,
    start_all = start_all,
}
