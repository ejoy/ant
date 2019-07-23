local debugutil = {}; debugutil.__index = debugutil


--return one value only
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

local function get_pcall_return(status,...)
    if not status then
        local args = {...}
        local err = args[1]
        io.stderr:write(string.format("Error:%s\n%s", status or "nil", err))
        log.error("Error:", status, err)
        return false
    else
        return true,...
    end
end

--support mult return value
function debugutil.try_r(fun,...)
    if debug.getregistry()["lua-debug"] then
        return fun(...)
    end
    return get_pcall_return(xpcall( fun,debug.traceback,... ))
end

return debugutil