local lfs = require "filesystem.local"
local config = require "config"
local vfs = require "vfs"

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
        res[#res+1] = path.."?"..cfg.arguments
    end
    res[#res+1] = pathlst[#pathlst]
    return res
end

local function compile_urls(urls)
    local path = assert(vfs.resource(urls))
    return lfs.path(path)
end

local function compile(pathstring)
    return compile_urls(split_path(pathstring))
end

local function compile_path(pathstring)
    local res = split_path(pathstring.."|")
    res[#res] = nil
    return res
end

local function compile_dir(urls, file)
    urls[#urls+1] = file
    local r = compile_urls(urls)
    urls[#urls] = nil
    return r
end

return {
    compile = compile,
    compile_path = compile_path,
    compile_dir = compile_dir,
}
