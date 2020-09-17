local ev = require 'backend.event'

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
        local n = 1
        while n <= #codes do
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
            n = n + 1
        end
    end
    if #vt > 0 then
        return "\x1b[" .. table.concat(vt, ";") .."m" .. text
    end
    return text
end

return function (msg, src, line)
    ev.emit('output', 'stdout', vtmode(msg), src, line)
end
