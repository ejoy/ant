local ecs = ...
local world = ecs.world
local w = world.w

local math3d 	    = require "math3d"

local imaterial     = ecs.require "ant.asset|material"
local imesh         = ecs.require "ant.asset|mesh"
local icompute      = ecs.require "ant.render|compute.compute"

local mc            = import_package "ant.math".constant
local hwi           = import_package "ant.hwi"
local bgfx          = require "bgfx"

local main_viewid<const> = hwi.viewid_get "main_view"

local terrain_module = require "terrain"
local ism = {}
local sm_sys = ecs.system "stone_mountain_system"

local sm_table = {}
local NOISE_RATIOS<const> = {
    0.88, 0.90, 0.92, 0.94
}

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
        x, z=x-1, z-1   --change to base 0
        local seed, offset_y, offset_x = z*x+idx, z+idx, x+idx
        return terrain_module.noise(x, z, noise_freq, noise_depth, seed, offset_y, offset_x)
    end
end

local function get_srt(offset, unit)
    for sidx, sm_info in ipairs(SM_SRT_INFOS) do
        local lb, rb, off = sm_info.scale.lb, sm_info.scale.rb, sm_info.offset
        for sm_idx, sm in pairs(sm_table) do
            local ix, iz = sm_idx & 0xffff, sm_idx >> 16

            local s_noise = gen_noise(ix+1, iz+1, sidx) * rb + lb
            local r_noise = gen_noise(ix+1, iz+1, sidx) * math.pi * 2
        
            local mesh_noise = (sm_idx + math.random(0, 4)) % 4 + 1
            local tx, tz = (ix + off - offset) * unit, (iz + off - offset) * unit
            sm[sidx] = {s = s_noise, r = r_noise, tx = tx, tz = tz, m = mesh_noise}
        end
    end
end

local function set_sm_property(width, height)
    local function has_block(x, z, m, n)
        for oz = 0, n - 1 do
            for ox = 0, m - 1 do
                local ix, iz = x + ox, z + oz
                if ix >= width or iz >= height then return nil end
                local sm_idx = (iz << 16) + ix
                if (not sm_table[sm_idx])then
                    return nil
                end
            end
        end
        return true
    end

    for sm_idx in pairs(sm_table) do
        local ix, iz = sm_idx & 0xffff, sm_idx >> 16
        local near_table = {true}
        for sidx=2, #SM_SRT_INFOS do
            if has_block(ix, iz, sidx, sidx) then
                near_table[sidx] = true
            end
        end
        if math.random(0, 1) > 0 then
            near_table[1] = nil
        end
        for idx, _ in pairs(near_table) do
            sm_table[sm_idx][idx] = {}
        end
    end
end

local function make_sm_noise(width, height, offset, unit)
    set_sm_property(width, height)
    get_srt(offset, unit)
end

local MERGE_MESH
local MESH_PARAMS

function sm_sys:init()
    local vbnums, ibnums
    MERGE_MESH, vbnums, ibnums = imesh.build_meshes{
        "/pkg/ant.landform/assets/meshes/mountain1.glb|meshes/Cylinder.002_P1.meshbin",
        "/pkg/ant.landform/assets/meshes/mountain2.glb|meshes/Cylinder.004_P1.meshbin",
        "/pkg/ant.landform/assets/meshes/mountain3.glb|meshes/Cylinder_P1.meshbin",
        "/pkg/ant.landform/assets/meshes/mountain4.glb|meshes/Cylinder.021_P1.meshbin",
    }

    local vboffset, iboffset = 0, 0
    local mp = {}
    for i=1, #vbnums do
        mp[i] = math3d.vector(vboffset, iboffset, ibnums[i], 0)
        vboffset = vboffset + vbnums[i]
        iboffset = iboffset + ibnums[i]
    end

    MESH_PARAMS = math3d.ref(math3d.array_vector(mp))
end

function sm_sys:entity_init()

end

local function idx2xz(idx, stride)
    return (idx % stride)+1, (idx // stride)+1
end

local QUEUE_MT = {
    empty = function(self) return 0 == #self end,
    pop = function (self) return table.remove(self, #self) end,
    find = function (self, v) for i=1, #self do if self[i] == v then return true end end end,
}

local NEW_MOUNTAIN_TYPE<const> = math3d.ref(math3d.vector(3, 0, 0, 0))

local function create_sm_entity(gid, indices, width, height, offset, unit)
    local memory = {}
    local meshes = {}
    for _, idx in ipairs(indices) do
        local ix, iz = idx2xz(idx, width)
        --TODO: we only consider one mask for one stone
        local sidx<const> = 1
        local info = SM_SRT_INFOS[sidx]
        local function scale_remap(nv, s, o)
            return nv * s + o
        end
        local s_noise = scale_remap(gen_noise(ix, iz, sidx), info.scale[2], info.scale[1])
        local r_noise = gen_noise(ix, iz, 1) * math.pi * 2

        local tx, tz = (ix - offset) * unit, (iz - offset) * unit
        local m = math3d.matrix{s=s_noise, r=math3d.quaternion{axis=mc.YAXIS, r=r_noise}, t=math3d.vector(tx, 0, tz)}
        m = math3d.transpose(m)
        local c1, c2, c3 = math3d.index(m, 1, 2, 3)
        local mesh_noise = math.random(1, 4)
        meshes[#meshes+1] = ('H'):pack(mesh_noise)
        memory[#memory+1] = ("%s%s%s"):format(math3d.serialize(c1), math3d.serialize(c2), math3d.serialize(c3))
    end

    local function build_mesh_indices_buffer(meshes)
        local s = table.concat(meshes, "")
        local MIN_SIZE<const> = 16 --uvec4 = 16 bytes
        local n = #s % MIN_SIZE
        if n > 0 then
            s = s .. ('\0'):rep(n)
        end
        return bgfx.create_index_buffer(bgfx.memory_buffer(s))
    end

    local mesh_indices_buffer = build_mesh_indices_buffer(meshes)

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
            simplemesh    = MERGE_MESH,
            material      = "/pkg/ant.landform/assets/materials/pbr_sm.material", 
            visible_state = "main_view|cast_shadow",
            stonemountain = {
                mesh_indices_buffer = mesh_indices_buffer,
            },
            draw_indirect = {
                instance_buffer = {
                    memory  = table.concat(memory, ""),
                    flag    = "r",
                    layout  = "t45NIf|t46NIf|t47NIf",
                    num     = drawnum,
                },
                indirect_type_NEED_REMOVED = NEW_MOUNTAIN_TYPE,
            },
            render_layer  = "foreground",
            on_ready = function(e)
                --TODO: need removed, srt data should be the same
                imaterial.set_property(e, "u_draw_indirect_type", NEW_MOUNTAIN_TYPE)
            end
        }
    }

    world:create_entity {
        policy = {
            "ant.render|compute_policy",
        },
        data = {
            material = "/pkg/ant.resources/materials/indirect/mountain.material",
            dispatch    = {
                size    = {((drawnum+63)//64), 0, 0},
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
                --just do it once
                icompute.dispatch(main_viewid, e.dispatch)
            end
        }
    }
end

function ism.create(groups, width, height, offset, unit)
    for gid, indices in pairs(groups) do
        --make_sm_noise(width, height, offset, unit)
        create_sm_entity(gid, indices, width, height, offset, unit)
    end
    
end

function sm_sys:entity_remove()
    for e in w:select "REMOVED stonemountain:in" do
        bgfx.destroy(e.stonemountain.mesh_indices_buffer)
    end
end

function sm_sys:exit()
    --TODO:
    log.info("MERGE_MESH need remove")
end


-- this random algorithm should move to other
local function update_sub_range_masks(width, height, range, ix, iz, masks)
    local gz, gx = (iz-1)*range, (ix-1)*range
    local noise = gen_noise(gx, gz, range)
    for z=1, range do
        for x=1, range do
            local zz, xx = gz+z, gx+x
            if xx <= width and zz <= height then
                local maskidx = (zz-1)*width+xx
                masks[maskidx] = noise > NOISE_RATIOS[range] and noise or 0
            end
        end
    end
end

function ism.create_random_sm(width, height)
    local masks = {}
    for ri=1, 4 do
        local ww, hh = (width+ri-1)//ri, (height+ri-1)//ri
        for iz=1, ww do
            for ix=1, hh do
                update_sub_range_masks(width, height, ri, ix, iz, masks)
            end
        end
    end
    assert(width * height==#masks)
    return masks
end

return ism
