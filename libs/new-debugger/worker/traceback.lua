local rdebug = require 'remotedebug'

local info = {}

local function findfield(t, f, level, name)
    local key, value
    while true do
        key, value = rdebug.next(t, key)
        if key == nil then
            break
        end
        if rdebug.type(key) == 'string' then
            local skey = rdebug.value(key)
            if level ~= 0 or skey ~= '_G' then
                if rdebug.type(value) == 'function' and rdebug.value(value) == f then
                    return name and (name .. '.' .. skey) or skey
                end
                if level < 2 and rdebug.type(value) == 'table' then
                    return findfield(value, f, level + 1, name and (name .. '.' .. skey) or skey)
                end
            end
        end
    end
end

local function pushglobalfuncname(f)
    if f then
        f = rdebug.value(f)
        return findfield(rdebug._G, f, 2)
    end
end
  
local function pushfuncname(f, info)
    local funcname = pushglobalfuncname(f)
    if funcname then
        return ("function '%s'"):format(funcname)
    elseif info.namewhat then
        return ("%s '%s'"):format(info.namewhat, info.name)
    elseif info.what == 'main' then
        return 'main chunk'
    elseif info.what ~= 'C' then
        return ('function <%s:%d>'):format(info.short_src, info.linedefined)
    else
        return '?'
    end
end

return function(msg, level)
    local s = {}
    s[#s + 1] = msg .. '\n'
    s[#s + 1] = 'stack traceback:'
    local last = rdebug.stacklevel()
    local n1 = last - level > 21 and 10 or -1
    while rdebug.getinfo(level, info) do
        local f = rdebug.getfunc(level)
        level = level + 1
        n1 = n1 - 1
        if n1 == 1 then
            s[#s + 1] = '\n\t...'
            level = last - 10
        else
            s[#s + 1] = ('\n\t%s:'):format(info.short_src)
            if info.currentline > 0 then
                s[#s + 1] = ('%d:'):format(info.currentline)
            end
            s[#s + 1] = " in "
            s[#s + 1] = pushfuncname(f, info)
            if info.istailcall then
                s[#s + 1] = '\n\t(...tail calls...)'
            end
        end
    end
    return table.concat(s)
end
