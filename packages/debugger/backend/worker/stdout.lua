local ev = require 'debugger.event'

local curmsg = ''
local cursrc
local curline
local ignore

return function (msg, src, line)
    curmsg = curmsg .. msg
    cursrc  = src  and src  or cursrc
    curline = line and line or curline

    if ignore then
        if curmsg:sub(1,1) == ignore then
            curmsg = curmsg:sub(2) or ''
        end
        ignore = nil
    end

    while true do
        local pos = curmsg:find('[\r\n]')
        if not pos then
            cursrc  = src
            curline = line
            return
        end

        if pos == #curmsg then
            ignore = curmsg:sub(pos) == '\n' and '\r' or '\n'
        else
            local ln1 = curmsg:sub(pos,pos) or ''
            local ln2 = curmsg:sub(pos+1,pos+1) or ''
            if ln1 == '\n' and ln2 == '\r' then
                pos = pos + 1
            elseif ln1 == '\r' and ln2 == '\n' then
                pos = pos + 1
            end
        end

        local result = curmsg:sub(1,pos) or ''
        curmsg = curmsg:sub(pos+1) or ''
        --stdout_vtmode(result)
        ev.emit('output', 'stdout', result, cursrc, curline)
        cursrc = src
        curline = line
    end
end
