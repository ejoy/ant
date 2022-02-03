local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"
local bgfx = require "bgfx"

local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local declmgr   = renderpkg.declmgr

local ientity = ecs.import.interface "ant.render|ientity"
local irender = ecs.import.interface "ant.render|irender"

local imaterial = ecs.import.interface "ant.asset|imaterial"


local is = ecs.system "init_system"

local cube_face_entities

local iblmb = world:sub {"ibl_updated"}
function is:init()
    --ecs.create_instance "/pkg/ant.test.ibl/assets/skybox.prefab"
    --ecs.create_instance "/pkg/ant.resources.binary/meshes/DamagedHelmet.glb|mesh.prefab"

    local simplemesh = {
        vb = {
            start = 0, num = 3,
            {
                handle = bgfx.create_vertex_buffer(bgfx.memory_buffer("fff", {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0}), declmgr.get "p3".handle)
            },
        }
    }

    local function create_face_entity(facename)
        return ecs.create_entity{
            policy = {
                "ant.render|simplerender",
                "ant.general|name",
            },
            data = {
                simplemesh = simplemesh,
                material = "/pkg/ant.test.ibl/assets/cubeface.material",
                scene = {srt={}},
                reference = true,
                filter_state = "",
                name = facename,
            }
        }
    end

    cube_face_entities = {
        create_face_entity "+x",
        create_face_entity "-x",

        create_face_entity "+y",
        create_face_entity "-y",

        create_face_entity "+z",
        create_face_entity "-z",
    }
end

function is:data_changed()
    -- for _, eid in iblmb:unpack() do
    --     local ibl = world[eid]._ibl
    --     imaterial.set_property(eid, "s_skybox", {stage=0, texture={handle=ibl.irradiance.handle}})
    -- end
end

local sample_count<const> = 2048
local face_size<const> = 256

local cLambertian<const>   = 0;
local cGGX       <const>   = 1;
local cCharlie   <const>   = 2;

--[[
#define u_roughness     u_ibl_params.x
#define u_sampleCount   u_ibl_params.y
#define u_width         u_ibl_params.z
#define u_lodBias       u_ibl_params.w

#define u_distribution  u_ibl_params1.x
#define u_currentFace   u_ibl_params1.y
#define u_isGeneratingLUT u_ibl_params1.z
]]

local ibl_properties = {
    irradiance = {
        u_ibl_params = {0.0, sample_count, face_size, 0.0},
        u_ibl_params1= {cLambertian, 0.0, 0.0, 0.0},
    },
    prefilter = {
        u_ibl_params = {0.0, sample_count, face_size, 0.0},
        u_ibl_params1= {cGGX, 0.0, 0.0, 0.0},
    },
    LUT = {
        u_ibl_params = {0.0, 0.0, 0.0, 0.0},
        u_ibl_params1= {0.0, 0.0, 1.0, 0.0},
    }
}

local viewid = viewidmgr.generate "cubeface_viewid"
function is:render_submit()

    -- do for irradiance
    local irradiance_properties = ibl_properties.irradiance
    for faceidx, e in ipairs(cube_face_entities) do
        w:sync("render_object:in", e)
        local ro = e.render_object
        imaterial.set_property(e, "u_ibl_params", irradiance_properties.u_ibl_params)
        imaterial.set_property(e, "u_ibl_params1", irradiance_properties.u_ibl_params1)
        irender.draw(viewid, ro)
    end
end