local ecs = ...
local world = ecs.world
local w = world.w

local bgfx = require "bgfx"

local renderpkg = import_package "ant.render"
local sampler = renderpkg.sampler

local imaterial = ecs.require "ant.render|material"
local dtt_sys   = ecs.system "dynamic_texture_test_system"
local layoutmgr = import_package "ant.render".layoutmgr
local test_eid
local test_billboard
local layout    = layoutmgr.get "p3|t2"
local tex_handle 

local m={
    -1,-1,0,0,1,
    -1,1,0,0,0 ,
    1,-1,0,1,1,
    1,1,0,1,0,
}
function dtt_sys:init()

    test_billboard=world:create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.render|billboard"
        },
        data = {
            billboard=true,
            scene = {
                t = {0, 4.0,-4.0},
            },
            visible     = true,
            material = "/pkg/ant.test.features/assets/billboard_test.material",
            mesh_result={
                vb={
                    start=0,
                    num=4,
                    handle=bgfx.create_vertex_buffer(
                        bgfx.memory_buffer("fffff", m),
                        layout.handle
                    ),
                },
            },
            on_ready = function (e)
                local x, y, ww, hh = 0, 0, 1, 1
                local gen_mipmap = false
                local layernum = 1
                local texture_fmt = "RGBA8"
                local texture_flag = sampler{
                    MIN="LINEAR",
                    MAG="LINEAR",
                    U="CLAMP",
                    V="CLAMP",
                }
                tex_handle = bgfx.create_texture2d(ww, hh, gen_mipmap, layernum, texture_fmt, texture_flag)
                imaterial.set_property(e, "s_basecolor", tex_handle)
            end
        }
    }  
end



function dtt_sys:data_changed()

end


