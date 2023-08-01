local ecs   = ...
local world = ecs.world
local w     = world.w
local assetmgr  = import_package "ant.asset"
local setting = import_package "ant.settings".setting
local ENABLE_SHADOW<const> = setting:data().graphic.shadow.enable

local blur_sys = ecs.system "blur_system"
if not ENABLE_SHADOW then
    local function DEF_FUNC() end
    blur_sys.init = DEF_FUNC
    blur_sys.init_world = DEF_FUNC
    blur_sys.blur = DEF_FUNC
    return 
end

local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local fbmgr		= require "framebuffer_mgr"
local sampler = renderpkg.sampler

local bgfx = require "bgfx"

local icompute = ecs.import.interface "ant.render|icompute"
local ishadow	= ecs.import.interface "ant.render|ishadow"
local imaterial = ecs.import.interface "ant.asset|imaterial"

local vblur_viewid<const> = viewidmgr.get "vblur"
local hblur_viewid<const> = viewidmgr.get "hblur"

local blur_textures = {}
local blur_w
local blur_h

local thread_group_size<const> = 8

local flags<const> = sampler {
    MIN="LINEAR",
    MAG="LINEAR",
    U="CLAMP",
    V="CLAMP",
    BLIT="BLIT_COMPUTEWRITE",
}

local function create_vblur_entity()
    local dispatchsize = {
        blur_w / thread_group_size, blur_h / thread_group_size, 1
    }
   icompute.create_compute_entity(
        "vblur_builder", "/pkg/ant.resources/materials/vblur.material", dispatchsize)
end

local function create_hblur_entity()
    local dispatchsize = {
        blur_w / thread_group_size, blur_h / thread_group_size, 1
    }
   icompute.create_compute_entity(
        "hblur_builder", "/pkg/ant.resources/materials/hblur.material", dispatchsize)
end


local function blur_dispatch()
    local source_tex = blur_textures.source_texture_handle

    for e in w:select "vblur_builder material:in dispatch:in" do
        local dis = e.dispatch
        --local material = dis.material
        local mo = assetmgr.resource(e.material).object
        mo:set_attrib("s_image_input", icompute.create_image_property(source_tex, 0, 0, "r"))
        mo:set_attrib("s_image_output", icompute.create_image_property(blur_textures.vblur_texture_handle, 1, 0, "w"))
        --material.s_image_input = icompute.create_image_property(source_tex, 0, 0, "r")
        --material.s_image_output = icompute.create_image_property(blur_textures.vblur_texture_handle, 1, 0, "w")
        icompute.dispatch(vblur_viewid, dis)
        w:remove(e)
    end

    for e in w:select "hblur_builder material:in dispatch:in" do
        local dis = e.dispatch
--[[         local material = dis.material
        material.s_image_input = icompute.create_image_property(blur_textures.vblur_texture_handle, 0, 0, "r")
        material.s_image_output = icompute.create_image_property(blur_textures.hblur_texture_handle, 1, 0, "w") ]]
        local mo = assetmgr.resource(e.material).object
        mo:set_attrib("s_image_input", icompute.create_image_property(blur_textures.vblur_texture_handle, 0, 0, "r"))
        mo:set_attrib("s_image_output", icompute.create_image_property(blur_textures.hblur_texture_handle, 1, 0, "w"))
        icompute.dispatch(vblur_viewid, dis)
        w:remove(e)
    end

end


local function build_blur_textures()
    local s_setting = ishadow.setting()
    blur_w = s_setting.shadowmap_size * s_setting.split_num
    blur_h = s_setting.shadowmap_size
    local function check_destroy(handle)
        if handle then
            bgfx.destroy(handle)
        end
    end
    blur_textures.source_texture_handle = fbmgr.get_rb(ishadow.fb_index(), 1).handle
    check_destroy(blur_textures.vblur_texture_handle)
    blur_textures.vblur_texture_handle = bgfx.create_texture2d(blur_w, blur_h, false, 1, "R32F", flags)
    check_destroy(blur_textures.hblur_texture_handle)
    blur_textures.hblur_texture_handle = bgfx.create_texture2d(blur_w, blur_h, false, 1, "R32F", flags)
end

local function update_blur_texture_info()
    local sa = imaterial.system_attribs()
    sa:update("s_shadowmap", blur_textures.hblur_texture_handle)
end

function blur_sys:init()

end

function blur_sys:init_world()
    build_blur_textures()
end

function blur_sys:blur()
    create_vblur_entity()
    create_hblur_entity()
    blur_dispatch()
    update_blur_texture_info()
end