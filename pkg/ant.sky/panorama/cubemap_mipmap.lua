local ecs = ...
local world = ecs.world
local w = world.w

local renderpkg = import_package "ant.render"
local sampler   = renderpkg.sampler

local hwi       = import_package "ant.hwi"

local icompute = ecs.require "ant.render|compute.compute"

local thread_group_size<const> = 8

local cubemap_mipmap_sys = ecs.system "cubemap_mipmap_system"

local icubemap_mipmap = {}

local p2c_viewid = hwi.viewid_get "panorama2cubmap"

local cubemap_textures = {
    source = {
        facesize = 0,
        value  = nil,
        stage  = 0,
        mip    = 0,
        access = "r"
    },
    result = {
        value = nil,
        size = 0,
        mipmap_count = 0,
    }
}


local function build_cubemap_textures(facesize, cm_rbhandle)
    cubemap_textures.source.value = cm_rbhandle
    cubemap_textures.source.facesize  = facesize


    cubemap_textures.result.value = cm_rbhandle
    cubemap_textures.result.size  = facesize
    cubemap_textures.result.mipmap_count = math.log(facesize, 2) + 1
end

local function create_cubemap_entities()
    local size = cubemap_textures.result.size

    local mipmap_count = cubemap_textures.result.mipmap_count

    local function create_cubemap_compute_entity(dispatchsize, cubemap_mipmap)
        world:create_entity {
            policy = {
                "ant.render|compute",
            },
            data = {
                material    = "/pkg/ant.resources/materials/postprocess/gen_cubemap_mipmap.material",
                dispatch    ={
                    size    = dispatchsize,
                },
                cubemap_mipmap = cubemap_mipmap,
                compute     = true,
                cubemap_mipmap_builder      = true,
            }
        }
    end


    for i=1, mipmap_count - 1 do
        local s = size >> (i-1)
        local dispatchsize = {
            math.floor(s / thread_group_size), math.floor(s / thread_group_size), 6
        }
        local cubemap_mipmap = {
            mipidx = i-1,
        }
        create_cubemap_compute_entity(dispatchsize, cubemap_mipmap)

    end
end

function cubemap_mipmap_sys:render_preprocess()
    for e in w:select "cubemap_mipmap_builder dispatch:in cubemap_mipmap:in" do
        local dis = e.dispatch
        local material = dis.material
        local cubemap_mipmap = e.cubemap_mipmap
        --material.u_build_cubemap_mipmap_param = math3d.vector(cubemap_mipmap.mipidx, 0, 0, 0)
        material.s_source = icompute.create_image_property(cubemap_textures.result.value, 0, cubemap_mipmap.mipidx, "r")
        --cubemap_textures.result.value = bgfx.create_texturecube(256, true, 1, "RGBA16F", cubemap_flags)
        material.s_result = icompute.create_image_property(cubemap_textures.result.value, 1, cubemap_mipmap.mipidx + 1, "w")

        icompute.dispatch(p2c_viewid, dis)
        w:remove(e)
    end
end

function icubemap_mipmap.gen_cubemap_mipmap(facesize, cm_rbhandle)
    build_cubemap_textures(facesize, cm_rbhandle)
    create_cubemap_entities()
end

return icubemap_mipmap
