local lfs       = require "bee.filesystem"
local bgfx      = require "bgfx"
local platform  = require "bee.platform"
local vfs       = require "vfs"

local config
local compile
local compile_file
local init_config

if __ANT_EDITOR__ then
    local cr = import_package "ant.compile_resource"
    function compile_file(input)
        return cr.compile_file(config, input)
    end
    function compile(pathstring)
        local pos = pathstring:find("|", 1, true)
        if pos then
            local resource = assert(vfs.realpath(pathstring:sub(1,pos-1)))
            local realpath = compile_file(resource).."/"..pathstring:sub(pos+1):gsub("|", "/")
            if lfs.exists(realpath) then
                return realpath
            end
        else
            local realpath = vfs.realpath(pathstring)
            if realpath then
                return realpath
            end
        end
    end
    init_config = cr.init_config
else
    local function normalize(p)
        local stack = {}
        p:gsub('[^/|]*', function (w)
            if #w == 0 and #stack ~= 0 then
            elseif w == '..' and #stack ~= 0 and stack[#stack] ~= '..' then
                stack[#stack] = nil
            elseif w ~= '.' then
                stack[#stack + 1] = w
            end
        end)
        return table.concat(stack, "/")
    end
    function compile(pathstring)
        pathstring = normalize(pathstring)
        local realpath = vfs.realpath(pathstring)
        if realpath then
            return realpath
        end
    end
    init_config = vfs.resource_setting
end

local function init()
    local caps = bgfx.get_caps()
    local renderer = caps.rendererType:lower()
    config = init_config(("%s-%s"):format(platform.os, renderer))
end

return {
    init = init,
    compile = compile,
    compile_file = compile_file,
}
