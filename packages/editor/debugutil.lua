local debugutil = {}; debugutil.__index = debugutil


function debugutil.try(fun,...)
    if debug.getregistry()["lua-debug"] then
        return fun(...)
    end
    local status,ret = xpcall( fun,debug.traceback,... )
    if not status then
        io.stderr:write(string.format("Error:%s\n%s", status or "nil", ret))
        log.error("Error:", status, ret)
    end
    return ret,status
end

return debugutil