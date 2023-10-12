local lfs       = require "bee.filesystem"
local bgfx      = require "bgfx"
local platform  = require "bee.platform"
local vfs       = require "vfs"

local compile
local compile_file
local set_setting

if __ANT_RUNTIME__ then
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
    set_setting = vfs.resource_setting
else
    local cr = import_package "ant.compile_resource"
    if __ANT_EDITOR__ then
        compile_file = cr.compile_file
    else
        local compiled = {}
        function compile_file(input)
            if compiled[input] then
                return compiled[input]
            end
            local output = cr.compile_file(input)
            compiled[input] = output
            return output
        end
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
    set_setting = cr.set_setting
end

local TextureExtensions <const> = {
    noop       = platform.os == "windows" and "dds" or "ktx",
	direct3d11 = "dds",
	direct3d12 = "dds",
	metal      = "ktx",
	vulkan     = "ktx",
	opengl     = "ktx",
}

local function init()
    local caps = bgfx.get_caps()
    local renderer = caps.rendererType:lower()
    local texture = assert(TextureExtensions[renderer])
    local hd = caps.homogeneousDepth and true or nil
    local obl = caps.originBottomLeft and true or nil

    set_setting {
        os = platform.os,
        renderer = renderer,
        hd = hd,
        obl = obl,
        texture = texture,
    }
end

return {
    init = init,
    compile = compile,
    compile_file = compile_file,
}
