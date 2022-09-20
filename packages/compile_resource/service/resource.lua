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
    value = {0, 0, 0, 0},
    flag = "umwwvm+l*p-l",
    sampler = {
        MAG = "LINEAR",
        MIN = "LINEAR",
        U = "MIRROR",
        V = "MIRROR",
    },
    name = "<default>"
}

local textureByName = {}
local textureById = {}
local createQueue = {}
local destroyQueue = {}
local token = {}

local function asyncCreateTexture(name)
    if createQueue[name] then
        return
    end
    if destroyQueue[name] then
        destroyQueue[name] = nil
    end
    createQueue[name] = true
    createQueue[#createQueue+1] = name
    if #createQueue == 1 then
        ltask.wakeup(token)
    end
end

local function asyncDestroyTexture(name)
    if createQueue[name] then
        return
    end
    destroyQueue[name] = true
    destroyQueue[#destroyQueue+1] = name
    if #destroyQueue == 1 then
        ltask.wakeup(token)
    end
end

local S = {}

function S.texture_default()
    return DefaultTexture
end

function S.texture_create(name)
    local c = textureByName[name]
    if not c then
        local id = textureman.texture_create(DefaultTexture)
        local res = loadTexture(name)
        c = {
            name = name,
            input = res,
            output = {
                id = id,
                texinfo = res.info,
                sampler = res.sampler,
            },
        }
        textureByName[name] = c
        textureById[id] = c
        asyncCreateTexture(name)
    end
    return c.output
end


ltask.fork(function ()
    while true do
        ltask.wait(token)
        for i = 1, #destroyQueue do
            local name = destroyQueue[i]
            if destroyQueue[name] then
                destroyQueue[name] = nil
                local c = textureByName[name]
                bgfx.destroy(c.handle)
                c.handle = nil
                textureman.texture_set(c.output.id, DefaultTexture)
            end
        end
        while true do
            local name = table.remove(createQueue, 1)
            if not name then
                break
            end
            createQueue[name] = nil
            local c = textureByName[name]
            if not c.input then
                c.input = loadTexture(name)
            end
            local handle = createTexture(c.input)
            c.handle = handle
            c.input = nil
            textureman.texture_set(c.output.id, handle)
            ltask.sleep(0)
        end
    end
end)

local quit

ltask.fork(function ()
    bgfx.encoder_create "texture"
    local FrameNew = 0
    local FrameCur = 1
    local results = {}
    local OneMinute <const> = 30 * 60
    while not quit do
        if #createQueue == 0 then
            textureman.frame_new(FrameCur - FrameNew + 1, DefaultTexture, results)
            for i = 1, #results do
                local id = results[i]
                results[i] = nil
                local c = textureById[id]
                if c then
                    asyncCreateTexture(c.name)
                end
            end
            FrameNew = FrameCur - 1
        end
        if FrameCur % OneMinute == 0 then
            textureman.frame_old(OneMinute, DefaultTexture, results)
            for i = 1, #results do
                local id = results[i]
                results[i] = nil
                local c = textureById[id]
                if c then
                    asyncDestroyTexture(c.name)
                    print("Destroy Texture: " .. c.name)
                end
            end
        end
        FrameCur = FrameCur + 1
        textureman.frame_tick()
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
