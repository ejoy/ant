local ecs   = ...
local world = ecs.world
local w     = world.w
local setting = import_package "ant.settings"
local ENABLE_SHADOW<const> = setting:get "graphic/shadow/enable"

local shadow_blur_sys = ecs.system "shadow_blur_system"

local renderpkg = import_package "ant.render"
local hwi       = import_package "ant.hwi"
local fbmgr		= require "framebuffer_mgr"
local sampler = renderpkg.sampler

local bgfx = require "bgfx"

local icompute = ecs.require "ant.render|compute.compute"
local ishadow	= ecs.require "ant.render|shadow.shadowcfg"
local imaterial = ecs.require "ant.asset|material"

local vblur_viewid<const> = hwi.viewid_get "svblur"
local hblur_viewid<const> = hwi.viewid_get "shblur"

local blur_textures = {}
local blur_w
local blur_h

local thread_group_size<const> = 16

local flags<const> = sampler {
    MIN="LINEAR",
    MAG="LINEAR",
    U="CLAMP",
    V="CLAMP",
    BLIT="BLIT_COMPUTEWRITE",
}

function shadow_blur_sys:init_world()
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

    build_blur_textures()
    create_vblur_entity()
    create_hblur_entity()
end

function shadow_blur_sys:entity_init()
    for ve in w:select "INIT vblur_builder dispatch:in" do
        local dis = ve.dispatch
        dis.material.s_image_input = icompute.create_image_property(blur_textures.source_texture_handle, 0, 0, "r")
        dis.material.s_image_output= icompute.create_image_property(blur_textures.vblur_texture_handle, 1, 0, "w")        
    end

    for he in w:select "INIT hblur_builder dispatch:in" do
        local dis = he.dispatch
        dis.material.s_image_input = icompute.create_image_property(blur_textures.vblur_texture_handle, 0, 0, "r")
        dis.material.s_image_output= icompute.create_image_property(blur_textures.hblur_texture_handle, 1, 0, "w")
    end
end

function shadow_blur_sys:shadow_blur()

    local function blur_dispatch()
        for ve in w:select "vblur_builder dispatch:in" do
            local dis = ve.dispatch
            icompute.dispatch(vblur_viewid, dis)  
        end
    
        for he in w:select "hblur_builder dispatch:in" do
            local dis = he.dispatch
            icompute.dispatch(hblur_viewid, dis)
        end
    end

    local function update_blur_texture_info()
        imaterial.system_attrib_update("s_shadowmap", blur_textures.hblur_texture_handle)
    end

    blur_dispatch()
    update_blur_texture_info()
end