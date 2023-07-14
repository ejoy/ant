local ltask      = require "ltask"
local bgfx       = require "bgfx"
local datalist   = require "datalist"
local fastio     = require "fastio"
local textureman = require "textureman.server"
local cr         = require "thread.compile"

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
        h = bgfx.create_texture(readall(c.path), c.flag)
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

local DefaultTexture = {
    TEX2D = createTexture {
        info = {
            width = 1,
            height = 1,
            format = "RGBA8",
            mipmap = false,
            depth = 1,
            numLayers = 1,
            cubeMap = false,
            storageSize = 4,
            numMips = 1,
            bitsPerPixel = 32,
        },
        value = {0, 0, 0, 0},
        flag = "umwwvm+l*p-l",
        sampler = {
            MAG = "LINEAR",
            MIN = "LINEAR",
            U = "CLAMP",
            V = "CLAMP",
        },
        name = "<default2d>"
    },
    --TODO: not support 3d texture right now
    -- TEX3D = createTexture {
    --     info = {
    --         width = 1,
    --         height = 1,
    --         format = "RGBA8",
    --         mipmap = false,
    --         depth = 2,
    --         numLayers = 1,
    --         cubeMap = false,
    --         storageSize = 8,
    --         numMips = 1,
    --         bitsPerPixel = 32,
    --     },
    --     value = {
    --         0, 0, 0, 0, -- depth 1
    --         0, 0, 0, 0, -- depth 2
    --     },
    --     flag = "umwwvm+l*p-l",
    --     sampler = {
    --         MAG = "LINEAR",
    --         MIN = "LINEAR",
    --         U = "CLAMP",
    --         V = "CLAMP",
    --     },
    --     name = "<default3d>"
    -- },
    TEXCUBE = createTexture {
        info = {
            width = 1,
            height = 1,
            format = "RGBA8",
            mipmap = false,
            depth = 1,
            numLayers = 1,
            cubeMap = true,
            storageSize = 24,   -- 4 x 6
            numMips = 1,
            bitsPerPixel = 32,
        },
        value = {
            0, 0, 0, 0, --face 1
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0, --face 6
        },
        flag = "umwwvm+l*p-l",
        sampler = {
            MAG = "LINEAR",
            MIN = "LINEAR",
            U = "CLAMP",
            V = "CLAMP",
        },
        name = "<defaultcube>"
    },
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
    if textureByName[name].input then
        createQueue[name] = true
        createQueue[#createQueue+1] = name
        if #createQueue == 1 then
            ltask.wakeup(token)
        end
    else
        ltask.fork(function ()
            local c = textureByName[name]
            c.input = loadTexture(name)
            asyncCreateTexture(name)
        end)
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

local function which_texture_type(info)
    if info.cubemap then
        return "TEXCUBE"
    end

    return info.depth > 1 and "TEX3D" or "TEX2D"
end

function S.texture_create(name)
    local c = textureByName[name]
    if not c then
        local res = loadTexture(name)
        local textype = which_texture_type(res.info)
        local id = textureman.texture_create(assert(DefaultTexture[textype]))
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

local FrameLoaded = 0
local MaxFrameLoaded <const> = 64
local rt_table = {}

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
                local textype = which_texture_type(c.output.texinfo)
                textureman.texture_set(c.output.id, DefaultTexture[textype])
            end
        end
        while true do
            local name = table.remove(createQueue, 1)
            if not name then
                break
            end
            while FrameLoaded > MaxFrameLoaded do
                ltask.sleep(10)
            end
            createQueue[name] = nil
            local c = textureByName[name]
            local handle = createTexture(c.input)
            c.handle = handle
            c.input = nil
            textureman.texture_set(c.output.id, handle)
            FrameLoaded = FrameLoaded + 1
            ltask.sleep(0)
        end
    end
end)

local update; do
    local FrameNew = 0
    local FrameCur = 1
    local results = {}
    local UpdateNewInterval <const> = 30 *  1 --  1s
    local UpdateOldInterval <const> = 30 * 60 -- 60s
    local InvalidTexture <const> = ("HH"):pack(DefaultTexture.TEX2D & 0xffff, DefaultTexture.TEXCUBE & 0xffff)
    function update()
        if FrameCur % UpdateNewInterval == 0 then
            if #createQueue == 0 then
                textureman.frame_new(FrameCur - FrameNew + 1, InvalidTexture, results)
                for i = 1, #results do
                    local id = results[i]
                    local c = textureById[id]
                    if c then
                        asyncCreateTexture(c.name)
                    end
                end
                FrameNew = FrameCur - 1
            end
        end
        if FrameCur % UpdateOldInterval == 0 then
            textureman.frame_old(UpdateOldInterval, InvalidTexture, results)
            for i = 1, #results do
                local id = results[i]
                local c = textureById[id]
                if c and (not rt_table[id]) then
                    asyncDestroyTexture(c.name)
                    print("Destroy Texture: " .. c.name)
                end
            end
        end
        FrameCur = FrameCur + 1
        FrameLoaded = 0
        textureman.frame_tick()
    end
end

function S.texture_timestamp(rtid_table)
    local id_table = {}
    for idx = 1, #rtid_table do
        id_table[#id_table+1] = rtid_table[idx]
    end
    local timestamp_table = textureman.texture_timestamp(id_table)
    local result_table = {}
    for idx = 1, #rtid_table do
        result_table[rtid_table[idx]] = timestamp_table[idx]
    end
    return result_table -- rt_id:timestamp
end

function S.texture_register_id()
    local rt_id = textureman.texture_create(DefaultTexture["TEX2D"])
    rt_table[rt_id] = true
    return rt_id
end

function S.texture_set_handle(rt_id, rt_handle)
    textureman.texture_set(rt_id, rt_handle)
end

function S.texture_destroy_handle(rt_id)
    textureman.texture_set(rt_id, DefaultTexture["TEX2D"])
    return true 
end

return {
    S = S,
    update = update
}
