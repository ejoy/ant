local ecs = ...
local world = ecs.world
local w = world.w

local math3d 	    = require "math3d"
local assetmgr      = import_package "ant.asset"
local imaterial     = ecs.require "ant.render|material"
local imesh         = ecs.require "ant.asset|mesh"
local icompute      = ecs.require "ant.render|compute.compute"
local irender       = ecs.require "ant.render|render"

local mc            = import_package "ant.math".constant
local hwi           = import_package "ant.hwi"
local bgfx          = require "bgfx"

local main_viewid<const> = hwi.viewid_get "main_view"

local lnoise = require "noise"

local sm_sys = ecs.system "stone_mountain_system"
local DEFAULT_SIZE<const> = 100
local NOISE_RATIO<const> = 0.88

local SM_SRT_INFOS = {
    {scale = {0.064, 0.064}, offset = 0.5}, 
    {scale = {0.064, 0.200}, offset = 0.1}, 
    {scale = {0.125, 0.250}, offset = 1.5},
    {scale = {0.350, 0.250}, offset = 2.0}
}

local gen_noise; do
    local noise_freq<const> = 4
    local noise_depth<const> = 4
    function gen_noise(x, z, idx)
        idx = idx or 1
        local seed, offset_y, offset_x = z*x+idx, z+idx, x+idx
        return lnoise.perlin2d(x, z, noise_freq, noise_depth, seed, offset_y, offset_x)
    end
end

local MERGE_MESH
local MESH_PARAMS

local function check_vec(vec)
    if #vec > 4 then
        error("Invalid data")
    end
    for i=#vec+1, 4 do
        vec[i] = 0
    end
    return vec
end

local function init_mountain_mesh(meshbins)
    local mesh = imesh.build_meshes(meshbins)
    MERGE_MESH = mesh.mesh

    MESH_PARAMS = math3d.ref(math3d.array_vector{
        math3d.vector(check_vec(mesh.vboffsets)), math3d.vector(check_vec(mesh.iboffsets)), math3d.vector(check_vec(mesh.ibnums))
    })
end

local function create_sm_entity(gid, indices, mountain_material, cs_material, meshbins)
    if MERGE_MESH == nil then
        init_mountain_mesh(meshbins)
    end
    local memory, meshes = {}, {}
    for _, index in ipairs(indices) do
        local coord = index.coord
        local ix, iz = coord[1], coord[2]
        local sidx<const> = index.sidx
        assert(1 <= sidx and sidx <= 4)
        local info = SM_SRT_INFOS[sidx]
        local function scale_remap(nv, s, o)
            return nv * s + o
        end
        local s_noise = scale_remap(gen_noise(ix, iz, sidx), info.scale[2], info.scale[1])
        local r_noise = gen_noise(ix, iz, sidx) * math.pi * 2
        local t_noise = info.offset * (math.random(0, 2) - 1) -- random generate 3 value: -info.offset, 0, info.offset
        local m = math3d.matrix{s=s_noise, r=math3d.quaternion{axis=mc.YAXIS, r=r_noise}, t=math3d.add(math3d.vector(t_noise, 0, t_noise), math3d.vector(index.pos))}
        m = math3d.transpose(m)
        local c1, c2, c3 = math3d.index(m, 1, 2, 3)
        memory[#memory+1] = ("%s%s%s"):format(math3d.serialize(c1), math3d.serialize(c2), math3d.serialize(c3))

        local mesh_noise = math.random(1, 4)
        meshes[#meshes+1] = ('H'):pack(mesh_noise)
    end

    local mesh_indices_buffer = bgfx.create_index_buffer(irender.align_buffer(table.concat(meshes, "")), "dr")

    assert(#memory == #indices)
    local drawnum = #memory

    local di_eid = world:create_entity {
        group = gid,
        policy = {
            "ant.render|simplerender",
            "ant.landform|stonemountain",
            "ant.render|draw_indirect"
         },
        data = {
            scene         = {},
            mesh_result   = MERGE_MESH,
            material      = mountain_material,
            visible       = true,
            visible_masks = "main_view|cast_shadow",
            stonemountain = {
                handle = mesh_indices_buffer,
            },
            draw_indirect = {
                instance_buffer = {
                    memory  = table.concat(memory, ""),
                    layout  = "t45NIf|t46NIf|t47NIf",
                    flag    = "r",
                    num     = drawnum,
                    size    = DEFAULT_SIZE
                },
            },
            render_layer  = "foreground",
        }
    }

    world:create_entity {
        policy = {
            "ant.render|compute",
        },
        data = {
            material = cs_material,
            dispatch    = {
                size    = {((drawnum+63)//64), 1, 1},
            },
            on_ready = function (e)
                local die = world:entity(di_eid, "draw_indirect:in")
                local di = die.draw_indirect
                w:extend(e, "dispatch:in")
                local dis = e.dispatch
                local m = dis.material
                m.b_mesh_indices = {
                    type    = "b",
                    value   = mesh_indices_buffer,
                    stage   = 0,
                    access  = "r",
                }
                m.b_indirect_buffer = {
                    type    = "b",
                    value   = di.handle,
                    stage   = 1,
                    access  = "w",
                }

                m.u_mesh_params = MESH_PARAMS
                m.u_buffer_param = math3d.vector(drawnum, 0, 0, 0)
                --just do it once
                icompute.dispatch(main_viewid, e.dispatch)
                assetmgr.material_mark(e.dispatch.fx.prog)
            end
        }
    }
end

local function destroy_handle(h)
    if h then
        bgfx.destroy(h)
    end
end

function sm_sys:entity_remove()
    for e in w:select "REMOVED stonemountain:in" do
        e.stonemountain.handle = destroy_handle(e.stonemountain.handle)
    end
end

function sm_sys:exit()
    if MERGE_MESH then
        MERGE_MESH.vb.handle = destroy_handle(MERGE_MESH.vb.handle)
        if MERGE_MESH.ib then
            MERGE_MESH.ib.handle = destroy_handle(MERGE_MESH.ib.handle)
        end
    end
end

local ism = {}

-- masks is base0
function ism.create_random_sm(width, height)
    local masks = {}
    for iz=0, height-1 do
        for ix=0, width-1 do
            local noise = gen_noise(ix, iz)
            local maskidx = iz*width+ix
            masks[maskidx] = noise > NOISE_RATIO and noise or 0
        end
    end
    return masks
end

function ism.create(groups, mountain_material, cs_material, meshbins)

    for gid, indices in pairs(groups) do
        --make_sm_noise(width, height, offset, unit)
        create_sm_entity(gid, indices, mountain_material, cs_material, meshbins)
    end
end

return ism
