local clonefunc = require 'clonefunc'

local function calc_lines(f, src, tmp)
    local info = debug.getinfo(f, 'SL')
    local actives = src.activelines
    local defines = src.definelines
    local maxn = 0
    for l in pairs(info.activelines) do
        actives[l] = true
        maxn = math.max(maxn, l)
    end
    local startLn = info.linedefined
    local endLn = info.lastlinedefined
    if endLn == 0 then
        startLn = 1
        endLn = maxn
        tmp.maxline = math.max(tmp.maxline, maxn)
    else
        tmp.maxline = math.max(tmp.maxline, endLn)
    end
    local n = tmp.n + 1
    tmp.n = n
    for l = startLn, endLn do
        defines[l] = n
    end
    local id, n = clonefunc.proto(f)
    if id then
        for i = 1, n do
            local of = clonefunc.clone(f, i)
            calc_lines(of, src, tmp)
        end
    end
end

local function normalize(src, maxline)
    local actives = src.activelines
    local defines = src.definelines
    for i = 1, maxline do
        if actives[i] == nil then
            actives[i] = false
        end
        if defines[i] == nil then
            defines[i] = 0
        end
    end
end

return function (src, f)
    local tmp = { n = 0, maxline = 0 }
    src.maxline = 0
    src.activelines = { }
    src.definelines = { }
    calc_lines(f, src, tmp)
    normalize(src, tmp.maxline)
    return src
end
