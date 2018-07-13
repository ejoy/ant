local rdebug = require 'remotedebug'

local function initialize()
    return require 'new-debugger.master'
end

local function start()
    rdebug.start 'new-debugger.worker'
end

local function event(name, level, ...)
    local r
    rdebug.probe(name)
    return r
end

local function update()
    event 'update'
end

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

return {
    initialize = initialize,
    start = start,
    update = update,
}
