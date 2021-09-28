local cr       = import_package "ant.compile_resource"
local bgfx     = require "bgfx"
local datalist = require "datalist"
local fastio   = require "fastio"

local textures = {}

local mem_formats <const> = {
    RGBA8 = "bbbb",
    RGBA32F = "ffff",
}

local function readall(filename)
    return bgfx.memory_buffer(fastio.readall(filename:string()))
end

local function readall_s(filename)
    return fastio.readall_s(filename:string())
end

local function createTexture(c)
    local h
    if c.value then
        local ti = c.info
        local v = c.value
        local memfmt = assert(mem_formats[ti.format], "not support memory texture format")
        local m = bgfx.memory_buffer(memfmt, v)
        if ti.cubeMap then
            assert(ti.width == ti.height)
            h = bgfx.create_texturecube(ti.width, ti.numMips ~= 0, ti.numLayers, ti.format, c.flag, m)
        elseif ti.depth == 1 then
            h = bgfx.create_texture2d(ti.width, ti.height, ti.numMips ~= 0, ti.numLayers, ti.format, c.flag, m)
        else
            assert(ti.depth > 1)
            error "not support 3d texture right now"
            h = bgfx.create_texture3d(ti.width, ti.height, ti.depth, ti.numMips ~= 0, ti.numLayers, ti.format, c.flag, m)
        end
    else
        local texdata = readall(c.path)
        h = bgfx.create_texture(texdata, c.flag)
    end
    bgfx.set_name(h, c.name)
    return h
end

local function loadTexture(name, urls)
    local c = datalist.parse(readall_s(cr.compile_dir(urls, "main.cfg")))
    c.name = name
    if not c.value then
        c.path = cr.compile_dir(urls, "main.bin")
    end
    return c
end

local DefaultTexture = createTexture {
    info = {
        width = 1,
        height = 1,
        format = "RGBA8",
        mipmap = false,
        depth = 1,
        numLayers = 1,
        cubemap = false,
        storageSize = 4,
        numMips = 1,
        bitsPerPixel = 32,
    },
    value = {0, 0, 0, 255},
    flags = "umwwvm+l*p-l",
    sampler = {
        MAG = "LINEAR",
        MIN = "LINEAR",
        U = "MIRROR",
        V = "MIRROR",
    },
    name = "<default>"
}

local queue = {}

local S = {}

function S.texture_create(name, urls)
    local res = textures[name]
    if res then
        return res
    end
    local c = loadTexture(name, urls)
    if false then
        queue[#queue+1] = c
        return {
            handle = DefaultTexture,
            uncomplete = true,
            texinfo = c.info,
            sampler = c.sampler
        }
    end
    return {
        handle = createTexture(c),
        texinfo = c.info,
        sampler = c.sampler
    }
end

function S.texture_complete(name)
end

function S.texture_destroy(res)
    bgfx.destroy(assert(res.handle))
end

return S
