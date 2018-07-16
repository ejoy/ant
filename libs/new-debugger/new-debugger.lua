local rdebug = require 'remotedebug'

local function event(name, level, ...)
    local r
    rdebug.probe(name)
    return r
end

local function start_master()
    return require 'new-debugger.backend.master'
end

local function start_worker()
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

    rdebug.start 'new-debugger.backend.worker'
    return function()
        event 'update'
    end
end

return {
    start_master = start_master,
    start_worker = start_worker,
}
