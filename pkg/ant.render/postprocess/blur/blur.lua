local ecs   = ...
local world = ecs.world
local w     = world.w
local setting = import_package "ant.settings"
local ENABLE_SHADOW<const> = setting:get "graphic/shadow/enable"

local blur_sys = ecs.system "blur_system"
if not ENABLE_SHADOW then
    local function DEF_FUNC() end
    blur_sys.init = DEF_FUNC
    blur_sys.init_world = DEF_FUNC
    blur_sys.blur = DEF_FUNC
    return 
end

local renderpkg = import_package "ant.render"
local hwi       = import_package "ant.hwi"
local fbmgr		= require "framebuffer_mgr"
local sampler = renderpkg.sampler

local bgfx = require "bgfx"

local icompute = ecs.require "ant.render|compute.compute"
local ishadow	= ecs.require "ant.render|shadow.shadow"
local imaterial = ecs.require "ant.asset|material"

local vblur_viewid<const> = hwi.viewid_get "vblur"
local hblur_viewid<const> = hwi.viewid_get "hblur"

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

    for e in w:select "vblur_builder dispatch:in" do
        local dis = e.dispatch
        local mi = dis.material
        
        mi.s_image_input = icompute.create_image_property(source_tex, 0, 0, "r")
        mi.s_image_output= icompute.create_image_property(blur_textures.vblur_texture_handle, 1, 0, "w")
        --material.s_image_input = icompute.create_image_property(source_tex, 0, 0, "r")
        --material.s_image_output = icompute.create_image_property(blur_textures.vblur_texture_handle, 1, 0, "w")
        icompute.dispatch(vblur_viewid, dis)
        w:remove(e)
    end

    for e in w:select "hblur_builder dispatch:in" do
        local dis = e.dispatch
--[[         local material = dis.material
        material.s_image_input = icompute.create_image_property(blur_textures.vblur_texture_handle, 0, 0, "r")
        material.s_image_output = icompute.create_image_property(blur_textures.hblur_texture_handle, 1, 0, "w") ]]
        local mi = dis.material
        mi.s_image_input = icompute.create_image_property(blur_textures.vblur_texture_handle, 0, 0, "r")
        mi.s_image_output= icompute.create_image_property(blur_textures.hblur_texture_handle, 1, 0, "w")
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
    imaterial.system_attrib_update("s_shadowmap", blur_textures.hblur_texture_handle)
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