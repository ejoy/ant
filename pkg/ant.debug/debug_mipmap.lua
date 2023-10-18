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
local cache_texture = {}

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


function idm.convert_to_debug_mipmap()
    for e in w:select "material?in" do
        local r = assetmgr.resource(e.material)
        local color_attrib = r.attrib["s_basecolor"]
        if color_attrib and (not cache_texture[color_attrib.value]) then
            local id = color_attrib.value
            local texture_content = ltask.call(ServiceResource, "texture_content", id)
            local texinfo, flag, format = texture_content.texinfo, texture_content.flag, texture_content.texinfo.format
            assert(chain_info.format == format, "debug mipmap texture format should be same as color texture format!\n")
            cache_texture[id] = assetmgr.textures[id] -- cache handle
            if texinfo.numMips > 1 then
                local cursize, curmip = math.max(texinfo.width, texinfo.height) / 2, 0
                assert(cursize <= 1024, "current texture max size greater than 2048!\n")
                local color_memory = ltask.call(ServiceResource, "texture_memory", id)
                while cursize >= 1 do
                    color_memory = image.replace_debug_mipmap(chain_info.memory, color_memory, curmip, curmip + 1)
                    cursize = cursize / 2
                    curmip = curmip + 1
                end
                local handle = bgfx.create_texture(color_memory, flag)
                ltask.call(ServiceResource, "texture_set_handle", id, handle) 
            end
        end
    end
end

function idm.restore_to_origin_mipmap()
    for id, handle in pairs(cache_texture) do
        if not assetmgr.invalid_texture(id) then
            ltask.call(ServiceResource, "texture_set_handle", id, handle)
            cache_texture[id] = nil 
        end
    end
end

function idm.reset_mipmap_level(id, first_mip)
    if not assetmgr.invalid_texture(id) then
        local texture_content = ltask.call(ServiceResource, "texture_content", id)
        local texture_memory = ltask.call(ServiceResource, "texture_memory", id)
        local new_handle = bgfx.create_texture(texture_memory, texture_content.flag, first_mip)
        ltask.call(ServiceResource, "texture_set_handle", id, new_handle)
    end
end

return idm