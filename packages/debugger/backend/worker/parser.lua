local undump = require 'backend.worker.undump'

local version

local function getproto(f)
    local cl, v = undump(string.dump(f))
    version = v
    return cl.f
end

local function getinfo(proto)
    local l = {}
    if version >= 504 then
        local n = proto.linedefined
        local abs = {}
        for _, line in ipairs(proto.abslineinfo) do
            abs[line.pc] = line.line
        end
        for i, line in ipairs(proto.lineinfo) do
            if line == -128 then
                n = assert(abs[i-1])
            else
                n = n + line
            end
            l[n] = true
        end
    else
        for _, line in ipairs(proto.lineinfo) do
            l[line] = true
        end
    end
    return {
        activelines = l,
        linedefined = proto.linedefined,
        lastlinedefined = proto.lastlinedefined,
    }
end

local function calc_lines(proto, src, tmp)
    local info = getinfo(proto)
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
    for i = 1, proto.sizep do
        calc_lines(proto.p[i], src, tmp)
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

local function parser_lines(src, f)
    local tmp = { n = 0, maxline = 0 }
    src.maxline = 0
    src.activelines = { }
    src.definelines = { }
    calc_lines(getproto(f), src, tmp)
    normalize(src, tmp.maxline)
    return src
end

return function (src, content)
    local f = load(content)
    if f then
        src.si = {}
        parser_lines(src.si, f)
    end
    return src
end
