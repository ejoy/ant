local serialize = import_package "ant.serialize"
local cr = import_package "ant.compile_resource"
local sha1 = require "sha1"
local image = require "image"
local bgfx = require "bgfx"

local fs = require "filesystem"
local lfs = require "filesystem.local"

local function get_raw_file(texfile)
    local c = cr.read_file(texfile)
    c = serialize.parse(texfile, c)
    return c.path
end

local function split_metallic_roughness(filename, outputdir)
    local c = cr.read_file(filename)
    local info, m = image.parse(c, true)
    local fmt = image.get_format_name(info.format)
    assert(fmt == "RGBA8" or fmt == "RGB8")
    local texelsize = image.get_bits_pre_pixel(info.format) / 8

    local roughness_offset, metallic_offset = 1, 2  -- roughness in B channel, metallic in G channel
    local metallic_data, roughness_data = {}, {}
    for ih=1, info.h do
        for iw=1, info.w do
            local idx = (ih-1) * info.w + (iw-1)
            local offset = idx * texelsize
            local moffset = offset + metallic_offset
            metallic_data[#metallic_data+1] = m:sub(moffset, moffset+1)
            local roffset = offset + roughness_offset
            roughness_data[#roughness_data+1] = m:sub(roffset, roffset+1)
        end
    end

    local function default_tex_info(w, h, fmt)
        local bits = image.get_bits_pre_pixel(fmt)
        local s = (bits//8) * w * h
        return {
            width=w, height=h, format=fmt,
            numLayers=1, numMips=1, storageSize=s,
            bitsPerPixel=bits,
            depth=1, cubeMap=false,
        }
    end

    local function write_file(name, data)
        local ti = default_tex_info(info.w, info.h, "R8")
        local cc = image.encode_image(ti, bgfx.memory_buffer(table.concat(data, "")), {type="dds", format="R8", srgb=false})
        local n = sha1(cc) .. name
        local fn = outputdir / n
        local f<close> = lfs.open(fn, "wb")
        f:write(cc)
        return fn
    end

    return  write_file("_metallic.dds", metallic_data),
            write_file("_roughness.dds", roughness_data)
end

local function load_(filename, outdir)
    local c = cr.read_file(filename)
    c = serialize.parse(filename, c)
    local properties = c.properties

    local metallic_roughness = get_raw_file(properties.s_metallic_roughness.texture)
    local metallic, roughness = split_metallic_roughness(metallic_roughness, outdir)
    local res = {
        diffuse = get_raw_file(properties.s_basecolor.texture),
        normal = get_raw_file(properties.s_normal.texture),
        metallic = metallic,
        roughness = roughness,
    }

    local bin = serialize.pack(res)
    return {
        material = "material-" .. sha1(bin),
        value = res,
    }
end

local cache = {}
local function load(filename, outdir)
    local r = cache[filename]
    if r then
        return r
    end
    r = load_(filename, outdir)
    cache[filename] = r
    return r
end

return {
    load = load
}