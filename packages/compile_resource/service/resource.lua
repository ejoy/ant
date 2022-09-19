local ltask      = require "ltask"
local bgfx       = require "bgfx"
local datalist   = require "datalist"
local fastio     = require "fastio"
local textureman = require "textureman.server"
local cr         = import_package "ant.compile_resource"
import_package "ant.render".init_bgfx()

cr.init()

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
        local skip = 0
        local width = c.info.width
        local MaxWidth <const> = 512
        while width > MaxWidth do
            width = width // 2
            skip = skip + 1
        end
        local texdata = readall(c.path)
        h = bgfx.create_texture(texdata, c.flag, skip)
    end
    bgfx.set_name(h, c.name)
    return h
end

local function loadTexture(name)
    local c = datalist.parse(readall_s(cr.compile(name.."|main.cfg")))
    c.name = name
    if not c.value then
        c.path = cr.compile(name.."|main.bin")
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
    flag = "umwwvm+l*p-l",
    sampler = {
        MAG = "LINEAR",
        MIN = "LINEAR",
        U = "MIRROR",
        V = "MIRROR",
    },
    name = "<default>"
}

local texturebyname = {}
local queue = {}
local token = {}

local function asyncCreateTexture(name)
    if queue[name] then
        return
    end
    queue[name] = true
    queue[#queue+1] = name
    if #queue == 1 then
        ltask.wakeup(token)
    end
end

local S = {}

function S.texture_default()
    return DefaultTexture
end

function S.texture_create(name)
    local c = texturebyname[name]
    if not c then
        local id = textureman.texture_create(DefaultTexture)
        local res = loadTexture(name)
        c = {
            input = res,
            output = {
                id = id,
                texinfo = res.info,
                sampler = res.sampler,
            },
        }
        texturebyname[name] = c
        asyncCreateTexture(name)
    end
    return c.output
end

ltask.fork(function ()
    while true do
        ltask.wait(token)
        while true do
            local name = table.remove(queue, 1)
            if not name then
                break
            end
            queue[name] = nil
            local c = texturebyname[name]
            if not c.input then
                c.input = loadTexture(name)
            end
            local handle = createTexture(c.input)
            c.input = nil
            textureman.texture_set(c.output.id, handle)
            textureman.event_push(c.output.id)
            ltask.sleep(0)
        end
    end
end)

local quit

ltask.fork(function ()
    bgfx.encoder_create "texture"
    while not quit do
        bgfx.encoder_frame()
    end
    bgfx.encoder_destroy()
    ltask.wakeup(quit)
end)

function S.quit()
    quit = {}
    ltask.wait(quit)
    ltask.quit()
end

return S
