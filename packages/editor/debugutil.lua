local debugutil = {}; debugutil.__index = debugutil


function debugutil.try(fun,...)
    if debug.getregistry()["lua-debug"] then
        return fun(...)
    end
    local status,err,ret = xpcall( fun,debug.traceback,... )
    if not status then
        io.stderr:write("Error:%s\n%s", status or "nil", err)
        log.error_a("Error:%s\n%s", status, err)
    end
    return ret
end

return debugutil