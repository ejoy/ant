local ecs = ...
local world = ecs.world
local w = world.w

local bgfx = require "bgfx"

local renderpkg = import_package "ant.render"
local sampler = renderpkg.sampler

local imaterial = ecs.import.interface "ant.asset|imaterial"

local dtt_sys = ecs.system "dynamic_texture_test_system"

local test_eid
local tex_handle 
function dtt_sys:init()
    test_eid = ecs.create_entity{
        policy = {
            "ant.render|render",
            "ant.general|name",
        },
        data = {
            name = "test_texture_entity",
            scene = {
                t = {10, 0.0, 0.0},
            },
            visible_state = "main_view",
            material = "/pkg/ant.test.features/assets/texture_test.material",
            mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
            on_ready = function (e)
                local x, y, ww, hh = 0, 0, 2, 2
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
                local layer, mip = 0, 0
                bgfx.update_texture2d(tex_handle, layer, mip, x, y, ww, hh, bgfx.memory_buffer("ffff", {
                    255, 255, 255, 255,
                    128, 128, 128, 128,
                }))

                imaterial.set_property(e, "s_basecolor", tex_handle)
            end
        }
    }
    
end

local kb_mb = world:sub{"keyboard"}

function dtt_sys:data_changed()
    for _, key, press in kb_mb:unpack() do
        if key == "G" and press == 0 then
            local layer, mip = 0, 0
            local x, y, ww, hh = 1, 1, 1, 1
            bgfx.update_texture2d(tex_handle, layer, mip, x, y, ww, hh, bgfx.memory_buffer("ffff", {
                0.8, 0.8, 0.8, 1.0
            }))
        end
    end
end