local ev = require 'common.event'

local foreground
local background
local bright
local underline
local negative

local function split(str)
    local r = {}
    str:gsub('[^;]+', function (w) r[#r+1] = tonumber(w) end)
    return r
end

local function vtmode(text)
    local vt = {}
    if foreground then
        vt[#vt+1] = foreground
    end
    if background then
        vt[#vt+1] = background
    end
    if bright then
        vt[#vt+1] = "1"
    end
    if underline then
        vt[#vt+1] = "4"
    end
    if negative then
        vt[#vt+1] = "7"
    end
    for vtstr in text:gmatch "\x1b%[([0-9;]+)m" do
        local codes = split(vtstr)
        for n = 1, #codes do
            local code = codes[n]
            if code == 0 then
                --reset
                foreground = nil
                background = nil
                bright = nil
                underline = nil
                negative = nil
            elseif code == 1 then
                -- bright
                bright = true
            elseif code == 4 then
                -- underline
                underline = true
            elseif code == 24 then
                -- no underline
                underline = false
            elseif code == 7 then
                -- negative
                negative = true
            elseif code == 27 then
                -- no negative
                negative = false
            elseif (code >= 30 and code <= 37) or (code >= 90 and code <= 97) then
                -- foreground
                foreground = tostring(code)
            elseif (code >= 40 and code <= 47) or (code >= 100 and code <= 107) then
                -- background
                background = tostring(code)
            elseif code == 39 then
                -- reset foreground
                foreground = nil
            elseif code == 40 then
                -- reset background
                background = nil
            elseif code == 38 then
                -- foreground
                if n + 2 <= #codes then
                    foreground = codes[n] .. ";" .. codes[n + 1] .. ";" .. codes[n + 2]
                    n = n + 2
                end
            elseif code == 48 then
                -- background
                if n + 2 <= #codes then
                    background = codes[n] .. ";" .. codes[n + 1] .. ";" .. codes[n + 2]
                    n = n + 2
                end
            end
        end
    end
    if #vt > 0 then
        return "\x1b[" .. table.concat(vt, ";") .."m" .. text
    end
    return text
end

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
        ev.emit('output', 'stdout',  vtmode(result), cursrc, curline)
        cursrc = src
        curline = line
    end
end
