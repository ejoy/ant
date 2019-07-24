local m = {}

local function get_pcall_return(ok,err,...)
    if not ok then
        io.stderr:write(string.format("Error: " .. err .. "\n"))
        log.error("Error: " .. err)
        return false
    else
        return true,err,...
    end
end

function m.try(fun,...)
    if debug.getregistry()["lua-debug"] then
        return true, fun(...)
    end
    return get_pcall_return(xpcall(fun,debug.traceback,...))
end

return m
