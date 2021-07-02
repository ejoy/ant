local fs = require "filesystem"
local config = require "config"

local function normalize(p)
    local stack = {}
    p:gsub('[^/]*', function (w)
        if #w == 0 and #stack ~= 0 then
        elseif w == '..' and #stack ~= 0 and stack[#stack] ~= '..' then
            stack[#stack] = nil
        elseif w ~= '.' then
            stack[#stack + 1] = w
        end
    end)
    return table.concat(stack, "/")
end

local function split(str)
    local r = {}
    str:gsub('[^|]*', function (w) r[#r+1] = w end)
    return r
end

local function split_path(pathstring)
    local pathlst = split(pathstring)
    local res = {}
    for i = 1, #pathlst - 1 do
        local path = normalize(pathlst[i])
        local ext = path:match "[^/]%.([%w*?_%-]*)$"
        local cfg = config.get(ext)
        res[#res+1] = path
        res[#res+1] = "?"
        res[#res+1] = cfg.arguments
        res[#res+1] = "/"
    end
    res[#res+1] = pathlst[#pathlst]
    return table.concat(res)
end

local function compile_url(url)
    return fs.path(url):localpath()
end

local function compile_dir(urllst)
    return compile_url(table.concat(urllst, "/"))
end

local function compile(pathstring)
    return compile_url(split_path(pathstring))
end

return {
    compile_dir = compile_dir,
    compile = compile,
}
