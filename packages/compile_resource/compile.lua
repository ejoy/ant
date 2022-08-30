local lfs = require "filesystem.local"
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

local function compile(pathstring)
    local urls = split(pathstring)
    if #urls == 1 then
        return lfs.path(vfs.realpath(pathstring))
    end
    for i = 1, #urls - 1 do
        urls[i] = normalize(urls[i])
    end
    return lfs.path(vfs.resource(urls))
end

return {
    compile = compile,
}
