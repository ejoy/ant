local ecs   = ...
local world = ecs.world
local w     = world.w

local ltask = require "ltask"
local image = require "image"
local bgfx  = require "bgfx"
local ServiceResource = ltask.queryservice "ant.resource_manager|resource"
local assetmgr = import_package "ant.asset"

local dm  = ecs.system "debug_mipmap_system"
local idm = {}

local texture_info = {
    {path = "/pkg/ant.debug/assets/debug_mipmap_texture/blue.texture"},     -- 1024x1024
    {path = "/pkg/ant.debug/assets/debug_mipmap_texture/green.texture"},    -- 512x512
    {path = "/pkg/ant.debug/assets/debug_mipmap_texture/red.texture"},      -- 256x256
    {path = "/pkg/ant.debug/assets/debug_mipmap_texture/cyan.texture"},     -- 128x128
    {path = "/pkg/ant.debug/assets/debug_mipmap_texture/yellow.texture"},   -- 64x64
    {path = "/pkg/ant.debug/assets/debug_mipmap_texture/pink.texture"},     -- 32x32 ~ 1x1
}
local chain_info = {}

function dm.init()
    for idx, texture in pairs(texture_info) do
        local ti = ltask.call(ServiceResource, "texture_create", texture.path)
        local texture_content = ltask.call(ServiceResource, "texture_content", ti.id)
        if idx == 1 then
            chain_info.id, chain_info.memory = ti.id, ltask.call(ServiceResource, "texture_memory", ti.id)
            chain_info.mips, chain_info.flag, chain_info.format = texture_content.texinfo.numMips, texture_content.flag, texture_content.texinfo.format
        else
            texture.id, texture.memory  = ti.id, ltask.call(ServiceResource, "texture_memory", ti.id)
        end
    end

    local tnum = #texture_info
    if tnum > 0 then
        local mipmap_num   = chain_info.mips
        for i = 2, tnum do
            local texinfo, mip_level = texture_info[i], i-1
            chain_info.memory = image.replace_debug_mipmap(texinfo.memory, chain_info.memory, 0, mip_level)
        end
        local last_texinfo = texture_info[tnum]
        for i = 1, mipmap_num - tnum do
            local dst_mip = i + tnum - 1
            chain_info.memory = image.replace_debug_mipmap(last_texinfo.memory, chain_info.memory, i, dst_mip)
        end
        local handle = bgfx.create_texture(chain_info.memory, chain_info.flag)
        ltask.call(ServiceResource, "texture_set_handle", chain_info.id, handle)
        ltask.call(ServiceResource, "texture_register_debug_mipmap_id", chain_info.id) -- prevent chain tid to destroy
    end
end

local function reset_texture_normal_mipmap(id, first_mip)
    local texture_content = ltask.call(ServiceResource, "texture_content", id)
    if texture_content.texinfo.numMips >= first_mip + 1 then
        local texture_memory = ltask.call(ServiceResource, "texture_memory", id)
        local new_handle = bgfx.create_texture(texture_memory, texture_content.flag, first_mip)
        ltask.call(ServiceResource, "texture_set_handle", id, new_handle)
    end
end

local function reset_texture_debug_mipmap(id, first_mip)
    local texture_content = ltask.call(ServiceResource, "texture_content", id)
    local texinfo, flag, format = texture_content.texinfo, texture_content.flag, texture_content.texinfo.format
    if chain_info.format ~= format then
        return
    end
    if texinfo.numMips > 1 then
        if type(texinfo.width) == "string" then
            texinfo.width = tonumber(texinfo.width)
        end
        if type(texinfo.height) == "string" then
            texinfo.height = tonumber(texinfo.height)
        end
        local max_size = math.max(texinfo.width, texinfo.height) / (2 ^ (first_mip + 1))
        local debug_mip, color_mip = 0, first_mip
        assert(max_size <= 1024, "current texture max size greater than 2048!\n")
        local color_memory = ltask.call(ServiceResource, "texture_memory", id)
        while max_size >= 1 do
            color_memory = image.replace_debug_mipmap(chain_info.memory, color_memory, debug_mip, color_mip + 1)
            debug_mip, color_mip =  debug_mip + 1, color_mip + 1
            max_size = max_size / 2
        end
        local handle = bgfx.create_texture(color_memory, flag, first_mip)
        ltask.call(ServiceResource, "texture_set_handle", id, handle) 
    end
end

function idm.reset_texture_mipmap(is_debug, first_mip)
    local most_detail_mip = first_mip and first_mip or 0
    local reset_cache = {}
    for e in w:select "material?in" do
        local r = assetmgr.resource(e.material)
        local color_attrib = r.attribs["s_basecolor"]
        if color_attrib and (not reset_cache[color_attrib.value]) then
            local id = color_attrib.value
            reset_cache[id] = true
            if is_debug then
                reset_texture_debug_mipmap(id, most_detail_mip)
            else
                reset_texture_normal_mipmap(id, most_detail_mip)
            end
        end
    end    
end

return idm