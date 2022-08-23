local sampler = import_package "ant.render".sampler
local stringify = import_package "ant.serialize".stringify

local pngparam = require "editor.texture.png_param"
local image = require "image"
local lfs = require "filesystem.local"
local fs = require "filesystem"

local function read_file(p)
    local f <close> = lfs.open(p)
    return f:read "a"
end

local function texture_info(w, h, fmt)
    return {
        width = w,
        height = h,
        format = fmt,
        mipmap = false,
        depth = 1,
        numLayers = 1,
        cubemap = false,
        storageSize = w*h*4,
        numMips = 1,
        bitsPerPixel = 32
    }

end

local function write_file(p, data)
    local f<close> = lfs.open(p, "wb")
    f:write(data)
end

local DEF_SAMPLER<const>        = pngparam.sampler()
local DEF_SAMPLER_FLAG<const>   = sampler(DEF_SAMPLER)
local function write_cfg(path, w, h, fmt)
    local config = {
        sampler = DEF_SAMPLER,
        flag	= DEF_SAMPLER_FLAG,
        info    = texture_info(w, h, fmt),
    }

    write_file(path, stringify(config))
end

return function (input, output, setting, localpath)
    local pnginput = fs.path(input)
    pnginput:replace_extension "png"
    local filecontent = read_file(localpath(pnginput))
    local info
    filecontent, info = image.png.convert(filecontent)

    if not filecontent then
		return false, "convert png failed"
	end

    write_cfg(output / "main.cfg", info.width, info.height, info.format)
    write_file(output / "main.bin", filecontent)
	return true, {pnginput}
end
