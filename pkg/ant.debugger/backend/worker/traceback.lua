local rdebug = require 'remotedebug.visitor'
local hookmgr = require 'remotedebug.hookmgr'
local source = require 'backend.worker.source'
local luaver = require 'backend.worker.luaver'

local info = {}

local function shortsrc(source, maxlen)
    maxlen = maxlen or 60
    local type = source:sub(1,1)
    if type == '=' then
        if #source <= maxlen then
            return source:sub(2)
        else
            return source:sub(2, maxlen)
        end
    elseif type == '@' then
        if #source <= maxlen then
            return source:sub(2)
        else
            return '...' .. source:sub(#source - maxlen + 5)
        end
    else
        local nl = source:find '\n'
        maxlen = maxlen - 15
        if #source < maxlen and nl == nil then
            return ('[string "%s"]'):format(source)
        else
            local n = #source
            if nl ~= nil then
                n = nl - 1
            end
            if n > maxlen then
                n = maxlen
            end
            return ('[string "%s..."]'):format(source:sub(1, n))
        end
    end
end

local function shortpath(path)
    local clientpath = source.clientPath(path)
    if clientpath:sub(1,2) == "./" and #clientpath > 2 then
        clientpath = clientpath:sub(3)
    end
    return shortsrc('@' .. clientpath)
end

local function getshortsrc(src)
    if src.sourceReference then
        local code = source.getCode(src.sourceReference)
        return shortsrc(code)
    elseif src.path then
        return shortpath(src.path)
    elseif src.skippath then
        return shortpath(src.skippath)
    elseif info.source:sub(1,1) == '=' then
        return shortsrc(info.source)
    else
        -- TODO
        return '<unknown>'
    end
end

local function findfield(t, f, level)
    if level == 0 then
        return
    end
    local loct = rdebug.tablehashv(t, 5000)
    for i = 1, #loct, 2 do
        local key, value = loct[i], loct[i+1]
        if rdebug.type(key) == 'string' then
            local skey = rdebug.value(key)
            if not (level == 2 and skey == '_G') then
                local tvalue = rdebug.type(value)
                if (tvalue == 'function' or tvalue == 'c function') and rdebug.value(value) == f then
                    return skey
                end
                if tvalue == 'table' then
                    local res = findfield(value, f, level - 1)
                    if res then
                        return skey .. '.' .. res
                    end
                end
            end
        end
    end
end

local function pushglobalfuncname(f)
    f = rdebug.value(f)
    if f ~= nil then
        return findfield(rdebug._G, f, 2)
    end
end

local function pushfuncname(f)
    local funcname = pushglobalfuncname(f)
    if funcname then
        return ("function '%s'"):format(funcname)
    elseif info.namewhat ~= '' then
        return ("%s '%s'"):format(info.namewhat, info.name)
    elseif info.what == 'main' then
        return 'main chunk'
    elseif info.what ~= 'C' then
        local src = source.create(info.source)
        return ('function <%s:%d>'):format(getshortsrc(src), source.line(src, info.linedefined))
    else
        return '?'
    end
end

local function getwhere(message)
    local f, l = message:find ':[-%d]+: '
    if f and l then
        local where_path = message:sub(1, f - 1)
        local where_line = tonumber(message:sub(f + 1, l - 2))
        local where_src = source.create("@"..where_path)
        message = message:sub(l + 1)
        return message, where_src, where_line
    end
    return message
end

local function findfirstlua(message)
    local depth = 0
    while true do
        if not rdebug.getinfo(depth, "Sl", info) then
            return -1
        end
        if info.what ~= 'C' then
            return depth, message
        end
        depth = depth + 1
    end
end

local function replacewhere(flags, error)
    local errormessage = tostring(rdebug.value(error))
    if flags[1] == "syntax" then
        return findfirstlua(errormessage)
    end
    local message, where_src, where_line = getwhere(errormessage)
    if not where_src then
        return findfirstlua(message)
    end
    local depth = 0
    while true do
        if not rdebug.getinfo(depth, "Sl", info) then
            return findfirstlua(message)
        end
        if info.what ~= 'C' then
            local src = source.create(info.source)
            if src == where_src and where_line == info.currentline then
                return depth, ('%s:%d: %s'):format(getshortsrc(where_src), source.line(src, where_line), message)
            end
        end
        depth = depth + 1
    end
end

local function traceback(flags, error)
    local s = {}
    local level, message = replacewhere(flags, error)
    if level < 0 then
        return -1
    end
    s[#s + 1] = 'stack traceback:'
    local last = hookmgr.stacklevel()
    local n1 = ((last - level) > 21) and 10 or -1
    local opt = luaver.LUAVERSION >= 52 and "Slntf" or "Slnf"
    local depth = level
    while rdebug.getinfo(depth, opt, info) do
        depth = depth + 1
        n1 = n1 - 1
        if n1 == 1 then
            local n = last - 10 - depth
            s[#s + 1] = ("\n\t...\t(skipping %d levels)"):format(n);
            depth = last - 10
        else
            local src = source.create(info.source)
            s[#s + 1] = ('\n\t%s:'):format(getshortsrc(src))
            if info.currentline > 0 then
                s[#s + 1] = ('%d:'):format(source.line(src, info.currentline))
            end
            s[#s + 1] = " in "
            s[#s + 1] = pushfuncname(info.func)
            if info.istailcall then
                s[#s + 1] = '\n\t(...tail calls...)'
            end
        end
    end
    return level, message, table.concat(s)
end

return {
    traceback = traceback,
    pushglobalfuncname = pushglobalfuncname,
}
