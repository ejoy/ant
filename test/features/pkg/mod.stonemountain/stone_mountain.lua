local ecs = ...
local world = ecs.world
local w = world.w
local open_sm = false
local math3d 	= require "math3d"
local mathpkg	= import_package "ant.math"
local mc		= mathpkg.constant
local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local declmgr   = import_package "ant.render".declmgr
local bgfx 			= require "bgfx"
local assetmgr  = import_package "ant.asset"
local icompute = ecs.import.interface "ant.render|icompute"
local terrain_module = require "terrain"
local ism = ecs.interface "istonemountain"
local sm_sys = ecs.system "stone_mountain"
local sm_material
local ratio, width, height, section_size
local freq, depth, unit, offset = 4, 4, 10, 0
local is_build_sm = false
local instance_num = 0
-- mapping between instance idx and sm_idx
local real_to_sm_table = {}
local sm_to_real_table = {}
local sm_table = {}
-- 1. mapping between mesh_idx and sm_idx with size_idx with count_idx (before get_final_map)
-- 1. mapping between mesh_idx and sm_idx with size_idx (after get_final_map)
local mesh_to_sm_table = {
    [1] = {},
    [2] = {},
    [3] = {},
    [4] = {}
}
local sm_bms_to_mesh_table = {}

-- section_idx to sm_idx
local sections_sm_table = {
}

-- queue_idx to section_idx
local terrain_section_cull_table = {}

-- mesh_idx to mesh_origin_aabb
local mesh_aabb_table    = {}

local constant_buffer_table = {
    sm_srt_memory_buffer = nil, 
    sm_srt_buffer = nil,       -- instance buffer
    indirect_buffer_table = {}, -- indirect buffer of each mesh
    visibility_memory_table = {
        [1] = {}, [2] = {}, [3] = {}, [4] = {}
    }
}

local function calc_section_idx(idx)
    local x = (idx - 1) %  width
    local y = (idx - 1) // height
    return y // section_size * (height / section_size)  + x // section_size + 1
end

local function get_corner_table(center, extent)
    local lt = {x = center.x - extent.x, z = center.z + extent.z}
    local t  = {x = center.x,            z = center.z + extent.z}
    local rt = {x = center.x + extent.x, z = center.z + extent.z}
    local r  = {x = center.x + extent.x, z = center.z}
    local rb = {x = center.x + extent.x, z = center.z - extent.z}
    local b  = {x = center.x,            z = center.z - extent.z}
    local lb = {x = center.x - extent.x, z = center.z - extent.z}
    local l  = {x = center.x - extent.x, z = center.z}
    --return {lt = lt, t = t, rt = rt, r = r, rb = rb, b = b, lb = lb, l = l}
    return {[1] = lt, [2] = t, [3] = rt, [4] = r,[5] = rb, [6] = b, [7] = lb, [8]= l}
end

local function get_inter_table(center, extent)
    local ltt = {x = center.x - extent.x * 0.5, z = center.z + extent.z}
    local trt = {x = center.x + extent.x * 0.5, z = center.z + extent.z}
    local rtr = {x = center.x + extent.x      , z = center.z + extent.z * 0.5}
    local rrb = {x = center.x + extent.x      , z = center.z - extent.z * 0.5}
    local rbb = {x = center.x + extent.x * 0.5, z = center.z - extent.z}
    local blb = {x = center.x - extent.x * 0.5, z = center.z - extent.z}
    local lbl = {x = center.x - extent.x      , z = center.z - extent.z * 0.5}
    local llt = {x = center.x - extent.x      , z = center.z + extent.z * 0.5}
    --return {ltt = ltt, trt = trt, rtr = rtr, rrb = rrb, rbb = rbb, blb = blb, lbl = lbl, llt = llt}
    return {[1] = ltt, [2]  = trt, [3]  = rtr, [4]  = rrb, [5]  = rbb, [6]  = blb, [7]  = lbl, [8]  = llt} 
end

local function get_corner_range(corner_idx, extent)
    local extent_x = extent.x
    local extent_z = extent.z
    if corner_idx == 1 then -- lt
        return {[1] = {lb = 0, ub = extent_x},         [2] = {lb = -extent_z, ub = 0}}
    elseif corner_idx == 2 then -- t 
        return {[1] = {lb = -extent_x, ub = extent_x}, [2] = {lb = -extent_z, ub = 0}}
    elseif corner_idx == 3 then -- rt
        return {[1] = {lb = -extent_x, ub = 0},        [2] = {lb = -extent_z, ub = 0}}
    elseif corner_idx == 4 then -- r
        return {[1] = {lb = -extent_x, ub = 0},        [2] = {lb = -extent_z, ub = extent_z}}
    elseif corner_idx == 5 then -- rb
        return {[1] = {lb = -extent_x, ub = 0},        [2] = {lb = 0, ub = extent_z}}
    elseif corner_idx == 6 then -- b
        return {[1] = {lb = -extent_x, ub = extent_x}, [2] = {lb = 0, ub = extent_z}}
    elseif corner_idx == 7 then -- lb
        return {[1] = {lb = 0, ub = extent_x},         [2] = {lb = 0, ub = extent_z}}
    elseif corner_idx == 8 then -- l
        return {[1] = {lb = 0, ub = extent_x},         [2] = {lb = -extent_z, ub = extent_z}}
    end
end

local function get_inter_range(corner_idx, extent)
    local extent_x = extent.x
    local extent_z = extent.z
    if corner_idx == 1 then -- ltt
        return {[1] = {lb = -extent_x, ub = extent_x}, [2] = {lb = -extent_z, ub = 0}}
    elseif corner_idx == 2 then -- trt 
        return {[1] = {lb = -extent_x, ub = extent_x}, [2] = {lb = -extent_z, ub = 0}}
    elseif corner_idx == 3 then -- rtr
        return {[1] = {lb = -extent_x, ub = 0},        [2] = {lb = -extent_z, ub = extent_z}}
    elseif corner_idx == 4 then -- rrb
        return {[1] = {lb = -extent_x, ub = 0},        [2] = {lb = -extent_z, ub = extent_z}}
    elseif corner_idx == 5 then -- rbb
        return {[1] = {lb = -extent_x, ub = extent_x}, [2] = {lb = 0, ub = extent_z}}
    elseif corner_idx == 6 then -- blb
        return {[1] = {lb = -extent_x, ub = extent_x}, [2] = {lb = 0, ub = extent_z}}
    elseif corner_idx == 7 then -- lbl
        return {[1] = {lb = 0, ub = extent_x},         [2] = {lb = -extent_z, ub = extent_z}}
    elseif corner_idx == 8 then -- llt
        return {[1] = {lb = 0, ub = extent_x},         [2] = {lb = -extent_z, ub = extent_z}}
    end
end

local function get_center()
    local m_clamp = (ratio + 0.2) * 0.1 -- [0.02, 0.12]
    local b_clamp = 1 - m_clamp -- [0.88, 0.98]
    local tmp_center_table = {}
    for iy = 6, height - 6 do
      for ix = 6, width - 6 do
        local cur_index = ix - 1 + (iy - 1) * width + 1
        local offset_x = iy
        local offset_y = ix
        local seed = iy * ix
        local e = terrain_module.noise(ix - 1, iy - 1, freq, depth, seed, offset_y, offset_x)
        local is_center = e <= m_clamp or e >= b_clamp
        if is_center then
            local cur_center
            if e <= m_clamp then
                cur_center = 2 -- m 1+1
            else
                cur_center = 3-- b 2+1
            end

            for y_offset = -4, 4 do
                for x_offset = -4, 4 do
                    local nei_x, nei_y = iy + y_offset, ix + x_offset
                    local nei_index = nei_x - 1 + (nei_y - 1) * width + 1
                    if tmp_center_table[nei_index] then
                        is_center = false
                        goto continue
                    end
                end
            end
            ::continue::
            if is_center then
                tmp_center_table[cur_index] = cur_center
                sm_table[cur_index] = {}
                if cur_center == 3 then
                    sm_table[cur_index][1] = {}
                    sm_table[cur_index].center_stone = {t = 1, idx = 1} -- big 1
                else
                    sm_table[cur_index][2] = {}
                    sm_table[cur_index].center_stone = {t = 2, idx = 1} -- middle 1
                end
            end
        end
      end
  end 
  --sm_table[1].center_stone = {t = 1, idx = 1}
  for idx = 1, width * height do
    if not sm_table[idx].center_stone then
        sm_table[idx] = nil
    end
  end
end

local function get_count()
    for sm_idx, _ in pairs(sm_table) do
        local iy = (sm_idx - 1) // width -- real iy need add 1
        local ix = (sm_idx - 1) % width
        for size_idx = 1, 3 do
            local offset_x = iy * size_idx
            local offset_y = ix * size_idx
            local seed = sm_idx * size_idx
            if size_idx == 1 then -- big size
                if sm_table[sm_idx][1] then --center_stone:big1
                    sm_table[sm_idx][1].c = 1
                else
                    sm_table[sm_idx][1] = {c = 0}
                end
             elseif size_idx == 2 then
                local e = terrain_module.noise(ix, iy, freq, depth, seed, offset_y, offset_x) * (8 + 1 - 1) + 1
                e = math.floor(e)
                if sm_table[sm_idx][2] then -- center_stone:middle1
                    sm_table[sm_idx][2].c = e + 1
                else
                    sm_table[sm_idx][2] = {c = e}
                end
            else
                local e = terrain_module.noise(ix, iy, freq, depth, seed, offset_y, offset_x) * (16 + 1 - 1) + 1
                e = math.floor(e)
                sm_table[sm_idx][3] = {c = e} 
            end
        end
    end


end

local function get_map()
    for sm_idx, _ in pairs(sm_table) do
        for mesh_idx = 1, 4 do
            mesh_to_sm_table[mesh_idx][sm_idx] = {}   
        end
        sm_bms_to_mesh_table[sm_idx] = {}
        local iy = (sm_idx - 1) // width
        local ix = (sm_idx - 1) % width
        for size_idx = 1, 3 do
            if not sm_bms_to_mesh_table[sm_idx][size_idx] then
                sm_bms_to_mesh_table[sm_idx][size_idx] = {}
            end
            local count_sum = sm_table[sm_idx][size_idx].c
            if not count_sum then
                count_sum = 0
            end
            for count_idx = 1, count_sum do
                local mesh_idx = (sm_idx + iy + ix + count_idx + size_idx) % 4 + 1
                sm_bms_to_mesh_table[sm_idx][size_idx][count_idx] = mesh_idx
                if not mesh_to_sm_table[mesh_idx][sm_idx][size_idx] then
                    mesh_to_sm_table[mesh_idx][sm_idx][size_idx] = {} 
                end
                mesh_to_sm_table[mesh_idx][sm_idx][size_idx][count_idx] = true
            end     
        end
    end   
end

local function get_final_map()
    local fmt = "ffff"
    for sm_idx, _ in pairs(sm_table) do
        local vb = {[1] = 0, [2] = 0, [3] = 0, [4] = 0}
        local vm = {[1] = 0, [2] = 0, [3] = 0, [4] = 0}
        local vs = {[1] = 0, [2] = 0, [3] = 0, [4] = 0}
        for mesh_idx = 1, 4 do
            mesh_to_sm_table[mesh_idx][sm_idx] = {}   
        end
        if not sm_bms_to_mesh_table[sm_idx] then -- new sm_idx
            sm_bms_to_mesh_table[sm_idx] = {}
            local iy = (sm_idx - 1) // width
            local ix = (sm_idx - 1) % width
            for size_idx = 1, 3 do
                if sm_table[sm_idx][size_idx].s then
                    local mesh_idx = (sm_idx + iy + ix + size_idx) % 4 + 1
                    if not mesh_to_sm_table[mesh_idx][sm_idx][size_idx] then
                        mesh_to_sm_table[mesh_idx][sm_idx][size_idx] = {} 
                    end
                    sm_bms_to_mesh_table[sm_idx][size_idx] = mesh_idx
                    mesh_to_sm_table[mesh_idx][sm_idx][size_idx] = true                    
                end
            end
        else -- origin sm_table
            -- find mesh_idx of big middle small
            local b_mesh_idx, m_mesh_idx, s_mesh_idx
            if sm_table[sm_idx][1] then
                b_mesh_idx = sm_bms_to_mesh_table[sm_idx][1][1]
            end
            if sm_table[sm_idx][2].s then
                local middle_origin = sm_table[sm_idx][2].origin
                m_mesh_idx = sm_bms_to_mesh_table[middle_origin.sm_idx][middle_origin.size_idx][middle_origin.count_idx]
            end
            if sm_table[sm_idx][3].s then
                local small_origin = sm_table[sm_idx][3].origin
                s_mesh_idx = sm_bms_to_mesh_table[small_origin.sm_idx][small_origin.size_idx][small_origin.count_idx]
            end
            sm_bms_to_mesh_table[sm_idx] = {}
            if b_mesh_idx then
                sm_bms_to_mesh_table[sm_idx][1] = b_mesh_idx
                mesh_to_sm_table[b_mesh_idx][sm_idx] = {}
                mesh_to_sm_table[b_mesh_idx][sm_idx][1] = true
            end
            if m_mesh_idx then
                sm_bms_to_mesh_table[sm_idx][2] = m_mesh_idx
                mesh_to_sm_table[m_mesh_idx][sm_idx] = {}
                mesh_to_sm_table[m_mesh_idx][sm_idx][2] = true
            end
            if s_mesh_idx then
                sm_bms_to_mesh_table[sm_idx][3] = s_mesh_idx
                mesh_to_sm_table[s_mesh_idx][sm_idx] = {}
                mesh_to_sm_table[s_mesh_idx][sm_idx][3] = true
            end
        end
        for mesh_idx = 1, 4 do
            if mesh_to_sm_table[mesh_idx][sm_idx][1] then
                vb[mesh_idx] = 1
            end
            if mesh_to_sm_table[mesh_idx][sm_idx][2] then
                vm[mesh_idx] = 1
            end
            if mesh_to_sm_table[mesh_idx][sm_idx][3] then
                vs[mesh_idx] = 1
            end
        end
        sm_table[sm_idx].mesh_visibility = {}
        for mesh_idx = 1, 4 do
            sm_table[sm_idx].mesh_visibility[mesh_idx] = fmt:pack(table.unpack({vb[mesh_idx], vm[mesh_idx], vs[mesh_idx], 0}))
        end
    end     
end

local function get_scale()
    for sm_idx, _ in pairs(sm_table) do
        if sm_table[sm_idx] then
            local iy = (sm_idx - 1) // width
            local ix = (sm_idx - 1) % width
            for size_idx = 1, 3 do
                local count_sum = sm_table[sm_idx][size_idx].c
                sm_table[sm_idx][size_idx].temp_scale_table = {}
                local temp_scale_table = sm_table[sm_idx][size_idx].temp_scale_table
                if not count_sum then
                    count_sum = 0
                end
                for count_idx = 1, count_sum do
                    local offset_x = iy * size_idx * count_idx
                    local offset_y = ix * size_idx * count_idx
                    local seed = sm_idx * size_idx * count_idx
                    if size_idx == 1 then
                        local e = terrain_module.noise(ix, iy, freq, depth, seed, offset_y, offset_x) * (1.30 - 0.80) + 0.80
                        sm_table[sm_idx][size_idx].s = e
                        sm_table[sm_idx].center_stone.s = e
                    elseif size_idx == 2 then
                        local e = terrain_module.noise(ix, iy, freq, depth, seed, offset_y, offset_x) * (1.00 - 0.50) + 0.50
                        temp_scale_table[count_idx] = e
                    elseif size_idx == 3 then
                        local e = terrain_module.noise(ix, iy, freq, depth, seed, offset_y, offset_x) * (0.75 - 0.10) + 0.10
                        temp_scale_table[count_idx] = e     
                    end
                end
            end
            if sm_table[sm_idx].center_stone.t == 2 then
                sm_table[sm_idx].center_stone.s = sm_table[sm_idx][2].temp_scale_table[1]
            end
        end
    end
end

local function get_rotation()
    for sm_idx, _ in pairs(sm_table) do
        if sm_table[sm_idx] then
            local iy = (sm_idx - 1) // width
            local ix = (sm_idx - 1) % width
            for size_idx = 1, 3 do
                local count_sum = sm_table[sm_idx][size_idx].c
                sm_table[sm_idx][size_idx].temp_rotation_table = {}
                local temp_rotation_table = sm_table[sm_idx][size_idx].temp_rotation_table
                if not count_sum then
                    count_sum = 0
                end
                for count_idx = 1, count_sum do
                    local offset_x = iy * size_idx * count_idx
                    local offset_y = ix * size_idx * count_idx
                    local seed = sm_idx * size_idx * count_idx
                    local e = terrain_module.noise(ix, iy, freq + size_idx, depth + size_idx, seed, offset_y, offset_x) * 2 - 1
                    if size_idx == 1 then
                        sm_table[sm_idx][size_idx].r = e
                    else
                        temp_rotation_table[count_idx] = e
                    end
                end
            end
        end
    end
end

local function get_translation()
    -- center_stone b1 or m1
    for sm_idx, _ in pairs(sm_table) do
        local center_stone = sm_table[sm_idx].center_stone
        local size_idx, count_idx
        if center_stone.t == 1 then
            size_idx, count_idx = 1, 1
        else
            size_idx, count_idx = 2, 1
        end
        local iy = (sm_idx - 1) // width + 1
        local ix = (sm_idx - 1) % width + 1
        local offset_x = iy * size_idx
        local offset_y = ix * size_idx
        local seedx = sm_idx * size_idx * count_idx * ix
        local seedz = sm_idx * size_idx * count_idx * iy
        local ex = terrain_module.noise(ix, iy, freq, depth - 1, seedx, offset_x, offset_x)
        local ez = terrain_module.noise(ix, iy, freq - 1, depth, seedz, offset_y, offset_y)
        local mesh_idx = sm_bms_to_mesh_table[sm_idx][size_idx][count_idx]
        local scale = center_stone.s
        center_stone.center = {
            x = (ix + ex - offset - 1) * unit,
            z = (iy + ez - offset - 1) * unit,
        }
        sm_table[sm_idx][size_idx].t = center_stone.center
        local extent = {}
        extent.x, extent.z = mesh_aabb_table[mesh_idx].extent[1] * scale, mesh_aabb_table[mesh_idx].extent[3] * scale -- radius
        local corner_table = get_corner_table(center_stone.center, extent)
        local inter_table = get_inter_table(center_stone.center, extent)
        sm_table[sm_idx].b_corner_table = corner_table
        sm_table[sm_idx].b_inter_table = inter_table     
    end

    -- get middle_stone's translation
    -- get m_inter_table   
    local sm_m_table = {}
    for sm_idx, _ in pairs(sm_table) do
        local size_idx = 2
        local m_min = {x = 100000,  z = 100000}
        local m_max = {x = -100000, z = -100000}
        local cb = 1
        if sm_table[sm_idx].center_stone.t == 2 then
            cb = 2
        end
        local count_sum = sm_table[sm_idx][size_idx].c
        if not count_sum then
            count_sum = 0
        end
        for count_idx = cb , count_sum do
            local iy = sm_idx // width + 1
            local ix = sm_idx % width + 1
            local corner_idx = (iy * ix * count_idx + iy + ix + count_idx) % 8 + 1
            local corner_center = sm_table[sm_idx].b_corner_table[corner_idx]
            local scale = sm_table[sm_idx][size_idx].temp_scale_table[count_idx]
            local mesh_idx = sm_bms_to_mesh_table[sm_idx][size_idx][count_idx]
            local extent = {}
            extent.x, extent.z = mesh_aabb_table[mesh_idx].extent[1] * scale, mesh_aabb_table[mesh_idx].extent[3] * scale   -- radius
            local corner_range = get_corner_range(corner_idx, extent)
            local offset_x = iy * size_idx
            local offset_y = ix * size_idx
            local seedx = sm_idx * size_idx * count_idx * ix
            local seedz = sm_idx * size_idx * count_idx * iy
            local lb_x, ub_x = corner_range[1].lb, corner_range[1].ub
            local lb_z, ub_z = corner_range[2].lb, corner_range[2].ub
            local ex = terrain_module.noise(ix, iy, freq, depth - 1, seedx, offset_x, offset_x) * (ub_x - lb_x) + lb_x
            local ez = terrain_module.noise(ix, iy, freq - 1, depth, seedz, offset_y, offset_y) * (ub_z - lb_z) + lb_z
            local corner_x = ex + corner_center.x
            local corner_z = ez + corner_center.z
            local grid_x   = math.floor(corner_x // unit + offset)
            local grid_z   = math.floor(corner_z // unit + offset)
            local m_idx = grid_x - 1 + (grid_z - 1) * width + 1
            if not sm_table[m_idx] then
                sm_m_table[m_idx]={[1] = {}, [2] = {}, [3] = {}}
                sm_m_table[m_idx][2].s = sm_table[sm_idx][size_idx].temp_scale_table[count_idx]
                sm_m_table[m_idx][2].r = sm_table[sm_idx][size_idx].temp_rotation_table[count_idx]
                sm_m_table[m_idx][2].t = {x = corner_x, z = corner_z}
                sm_m_table[m_idx][2].origin = {sm_idx = sm_idx, size_idx = size_idx, count_idx = count_idx}
            else
                sm_table[m_idx][size_idx].t = {
                    x = corner_x,
                    z = corner_z
                }
                sm_table[m_idx][2].origin = {sm_idx = sm_idx, size_idx = size_idx, count_idx = count_idx}
            end
            if corner_x - extent.x < m_min.x then
                m_min.x = corner_x - extent.x
                end
            if corner_x + extent.x > m_max.x then
                m_max.x = corner_x + extent.x
            end
            if corner_z - extent.z < m_min.z then
                m_min.z = corner_z - extent.z
            end
            if corner_z + extent.z > m_max.z then
                m_max.z = corner_z + extent.z
            end
            local m_center = {x = (m_max.x + m_min.x) * 0.5, z = (m_max.z + m_min.z) * 0.5}
            local m_extent = {x = (m_max.x - m_min.x) * 0.5, z = (m_max.z - m_min.z) * 0.5}
            local inter_table = get_inter_table(m_center, m_extent)
            sm_table[sm_idx].m_inter_table = inter_table
            sm_table[sm_idx].outer_extent = m_extent
        end 
    end

    local sm_s_table = {}

    for sm_idx, _ in pairs(sm_table) do
        local size_idx = 3
        local count_sum = sm_table[sm_idx][size_idx].c
        if not count_sum then
            count_sum = 0
        end
        for count_idx = 1, count_sum do
            local scale = sm_table[sm_idx][size_idx].temp_scale_table[count_idx]
            local mesh_idx = sm_bms_to_mesh_table[sm_idx][size_idx][count_idx]
            local iy = sm_idx // width + 1
            local ix = sm_idx % width + 1
            local inter_idx = (size_idx * iy * ix * count_idx + iy + ix + count_idx) % 16 + 1
            local inter_center
            local extent = {}
            if inter_idx <= 8 then
                inter_center = sm_table[sm_idx].b_inter_table[inter_idx]
                extent.x, extent.z = mesh_aabb_table[mesh_idx].extent[1] * scale, mesh_aabb_table[mesh_idx].extent[3] * scale  -- radius
            else
                inter_idx = inter_idx - 8
                inter_center = sm_table[sm_idx].m_inter_table[inter_idx]
                extent.x, extent.z =  sm_table[sm_idx].outer_extent.x,  sm_table[sm_idx].outer_extent.z
            end
            local inter_range = get_inter_range(inter_idx, extent)
            local offset_x = iy * size_idx
            local offset_y = ix * size_idx
            local seedx = sm_idx * size_idx * count_idx * ix
            local seedz = sm_idx * size_idx * count_idx * iy
            local lb_x, ub_x = inter_range[1].lb, inter_range[1].ub
            local lb_z, ub_z = inter_range[2].lb, inter_range[2].ub
            local ex = terrain_module.noise(ix, iy, freq, depth - 1, seedx, offset_x, offset_x) * (ub_x - lb_x) + lb_x
            local ez = terrain_module.noise(ix, iy, freq - 1, depth, seedz, offset_y, offset_y) * (ub_z - lb_z) + lb_z
            local inter_x = ex + inter_center.x
            local inter_z = ez + inter_center.z
            local grid_x   = math.floor(inter_x // unit + offset)
            local grid_z   = math.floor(inter_z // unit + offset)
            local s_idx = grid_x - 1 + (grid_z - 1) * width + 1
            if not sm_table[s_idx] and not sm_m_table[s_idx] then
                sm_s_table[s_idx]={[1] = {}, [2] = {}, [3] = {}}
                sm_s_table[s_idx][3].s = sm_table[sm_idx][size_idx].temp_scale_table[count_idx]
                sm_s_table[s_idx][3].r = sm_table[sm_idx][size_idx].temp_rotation_table[count_idx]
                sm_s_table[s_idx][3].t = {x = inter_x, z = inter_z}
                sm_s_table[s_idx][3].origin = {sm_idx = sm_idx, size_idx = size_idx, count_idx = count_idx}
            elseif sm_table[s_idx] then
                sm_table[s_idx][3].t = {x = inter_x, z = inter_z}
                sm_table[s_idx][3].origin = {sm_idx = sm_idx, size_idx = size_idx, count_idx = count_idx}
            else
                sm_m_table[s_idx][3].s = sm_table[sm_idx][size_idx].temp_scale_table[count_idx]
                sm_m_table[s_idx][3].r = sm_table[sm_idx][size_idx].temp_rotation_table[count_idx]
                sm_m_table[s_idx][3].t = {x = inter_x, z = inter_z}
                sm_m_table[s_idx][3].origin = {sm_idx = sm_idx, size_idx = size_idx, count_idx = count_idx}             
            end
        end
    end 

    for sm_idx, m_stone in pairs(sm_m_table) do
        sm_table[sm_idx] = m_stone
    end  

    for sm_idx, s_stone in pairs(sm_s_table) do
        sm_table[sm_idx] = s_stone
    end
    get_final_map()
end

local function get_real_sm() 
    for sm_idx, _ in pairs(sm_table) do
        instance_num = instance_num + 1
        real_to_sm_table[instance_num] = sm_idx
        sm_to_real_table[sm_idx] = instance_num
    end
end

local function get_stone_aabb(sm_idx, size_idx)
    local stone = sm_table[sm_idx][size_idx]
    local stone_aabb = math3d.aabb()
    if stone.s then
        local center_x = mesh_aabb_table[sm_bms_to_mesh_table[sm_idx][size_idx]].center[1]
        local center_y = mesh_aabb_table[sm_bms_to_mesh_table[sm_idx][size_idx]].center[2]
        local center_z = mesh_aabb_table[sm_bms_to_mesh_table[sm_idx][size_idx]].center[3]
        local extent_x = mesh_aabb_table[sm_bms_to_mesh_table[sm_idx][size_idx]].extent[1]
        local extent_y = mesh_aabb_table[sm_bms_to_mesh_table[sm_idx][size_idx]].extent[2]
        local extent_z = mesh_aabb_table[sm_bms_to_mesh_table[sm_idx][size_idx]].extent[3]
        local stone_center = math3d.add(math3d.mul(stone.s, math3d.vector(center_x, center_y, center_z)), math3d.vector(stone.t.x, 0, stone.t.z))
        local stone_extent = math3d.mul(stone.s, math3d.vector(extent_x, extent_y, extent_z))
        stone_aabb = math3d.aabb(math3d.add(stone_center, stone_extent), math3d.sub(stone_center, stone_extent)) 
    end
    return stone_aabb
end

local function get_sections_sm()
    for sm_idx, _ in pairs(sm_table)do
        local section_idx = calc_section_idx(sm_idx)
        if not sections_sm_table[section_idx] then
            sections_sm_table[section_idx] = {sms = {}, aabb = math3d.ref(math3d.aabb())}
        end
        local big_aabb, middle_aabb, small_aabb = get_stone_aabb(sm_idx, 1), get_stone_aabb(sm_idx, 2), get_stone_aabb(sm_idx, 3)
        local cur_aabb
        local small_valid = math3d.aabb_isvalid(small_aabb)
        local middle_valid = math3d.aabb_isvalid(middle_aabb)
        local big_valid = math3d.aabb_isvalid(big_aabb)

        if not small_valid and not middle_valid and not big_valid then
            cur_aabb = math3d.aabb()
        elseif small_valid then
            cur_aabb = small_aabb
            if middle_valid then
                cur_aabb = math3d.aabb_merge(cur_aabb, middle_aabb)
            end
            if big_valid then
                cur_aabb = math3d.aabb_merge(cur_aabb, big_aabb)
            end
        elseif middle_valid then
            cur_aabb = middle_aabb
            if big_valid then
                cur_aabb = math3d.aabb_merge(cur_aabb, big_aabb)
            end
        else
            cur_aabb = big_aabb 
        end
        sections_sm_table[section_idx].sms[sm_idx] = true
        if not math3d.aabb_isvalid(sections_sm_table[section_idx].aabb) then
            sections_sm_table[section_idx].aabb = math3d.ref(cur_aabb)
        else
            if math3d.aabb_isvalid(cur_aabb) then
                sections_sm_table[section_idx].aabb = math3d.ref(math3d.aabb_merge(sections_sm_table[section_idx].aabb, cur_aabb))                
            end
        end
    end
end

local function record_sm_idx_to_terrain_field(tf, stone, sm_idx, size_idx)
    local mesh_idx = sm_bms_to_mesh_table[sm_idx][size_idx]
    local center_x, center_z = stone.t.x + offset * unit, stone.t.z + offset * unit
    local extent_x, extent_z = mesh_aabb_table[mesh_idx].extent[1] * stone.s, mesh_aabb_table[mesh_idx].extent[2] * stone.s
    local min_x, max_x = math.floor((center_x - extent_x) / unit) + 1, math.ceil((center_x + extent_x) / unit)
    local min_z, max_z = math.floor((center_z - extent_z) / unit), math.ceil((center_z + extent_z) / unit)
    for y = min_z, max_z do
        for x = min_x, max_x do
            local cur_idx= x - 1 + (y - 1) * width + 1
            tf[cur_idx].is_sm = true
        end
    end
end

local function set_terrain_sm()
     for e in w:select "shape_terrain st:update" do
        local st = e.st
        if st.prev_terrain_fields == nil then
            error "need define terrain_field, it should be file or table"
        end
        for sm_idx, stones in pairs(sm_table) do
            local big_stone, middle_stone, small_stone = stones[1], stones[2], stones[3]
            if big_stone.s then
                record_sm_idx_to_terrain_field(st.prev_terrain_fields, big_stone, sm_idx, 1)
            end
            if middle_stone.s then
                record_sm_idx_to_terrain_field(st.prev_terrain_fields, middle_stone, sm_idx, 2)
            end
            if small_stone.s then
                record_sm_idx_to_terrain_field(st.prev_terrain_fields, small_stone, sm_idx, 3)
            end
        end
    end 
end

function ism.create_sm_entity(r, ww, hh, off, un, f, d)
    open_sm = true
    ratio, width, height= r, ww, hh
    if off then
        offset = off
    end
    if un then
        un = unit
    end
    if f then
        freq = f
    end
    if d then
        depth = d
    end
    section_size = math.min(math.max(1, width > 4 and width//4 or width//2), 32)
    for center_idx = 1, width * height do
        sm_table[center_idx] = {[1] = {}, [2] = {}, [3] = {}} -- b m s
    end
    ecs.create_entity {
        policy = {
            "ant.render|render",
            "ant.general|name",
            "mod.stonemountain|stone_mountain",
         },
        data = {
            name          = "sm1",
            scene         = {},
            material      ="/pkg/mod.stonemountain/assets/pbr_sm.material", 
            visible_state = "main_view|cast_shadow",
            mesh          = "/pkg/mod.stonemountain/assets/mountain1.glb|meshes/Cylinder.002_P1.meshbin",
            stonemountain = true,
            sm_info       ={
                mesh_idx  = 1
            }
        },
    }   
    ecs.create_entity {
        policy = {
            "ant.render|render",
            "ant.general|name",
            "mod.stonemountain|stone_mountain",
         },
        data = {
            name          = "sm2",
            scene         = {},
            material      = "/pkg/mod.stonemountain/assets/pbr_sm.material", 
            visible_state = "main_view|cast_shadow",
            mesh          = "/pkg/mod.stonemountain/assets/mountain2.glb|meshes/Cylinder.004_P1.meshbin",
            stonemountain = true,
            sm_info       ={
                mesh_idx  = 2
            }
        },
    } 
    ecs.create_entity {
        policy = {
            "ant.render|render",
            "ant.general|name",
            "mod.stonemountain|stone_mountain",
         },
        data = {
            name          = "sm3",
            scene         = {},
            material      = "/pkg/mod.stonemountain/assets/pbr_sm.material", 
            visible_state = "main_view|cast_shadow",
            mesh          = "/pkg/mod.stonemountain/assets/mountain3.glb|meshes/Cylinder_P1.meshbin",
            stonemountain = true,
            sm_info       ={
                mesh_idx  = 3
            }
        },
    }  
    ecs.create_entity {
        policy = {
            "ant.render|render",
            "ant.general|name",
            "mod.stonemountain|stone_mountain",
         },
        data = {
            name          = "sm4",
            scene         = {},
            material      = "/pkg/mod.stonemountain/assets/pbr_sm.material", 
            visible_state = "main_view|cast_shadow",
            mesh          = "/pkg/mod.stonemountain/assets/mountain4.glb|meshes/Cylinder.021_P1.meshbin",
            stonemountain = true,
            sm_info       ={
                mesh_idx  = 4
            }
        },
    }   
end

function ism.get_sm_aabb(queue_name)
    if terrain_section_cull_table[queue_name] then
        local sm_aabb = math3d.ref(terrain_section_cull_table[queue_name].aabb)
        return sm_aabb 
    else
        return math3d.ref(math3d.aabb())
    end
end

local function create_sm_compute(sm_info, queue_name, mesh_idx)
    local dispatchsize = {
		math.floor((instance_num - 1) / 64) + 1, 1, 1
	}
    local dis = {}
	dis.size = dispatchsize
    local mo = sm_material.object
    dis.material = mo:instance()
    local mat = dis.material
    mat.b_indirect_vb   = constant_buffer_table.indirect_buffer_table[mesh_idx]
    mat.b_visibility_vb = sm_info.sm_visibility_table[queue_name] 
    mat.u_instance_params = sm_info.instance_params
    mat.u_indirect_params = math3d.vector(instance_num, 0, 0, 0)
	dis.fx = sm_material._data.fx
	return dis
end

local function do_sm_compute(sm_info, queue_name)
    icompute.dispatch(viewidmgr.get(queue_name), sm_info.dispatch_entity_table[queue_name])
end

local function update_sm_dyb(mesh_idx, queue_name, sm_info)
    bgfx.update(sm_info.sm_visibility_table[queue_name], 0, constant_buffer_table.visibility_memory_table[mesh_idx]["pre_depth"])
    if not sm_info.dispatch_entity_table[queue_name] then
        sm_info.dispatch_entity_table[queue_name] = create_sm_compute(sm_info, queue_name, mesh_idx)
    end
    do_sm_compute(sm_info, queue_name)
end

local function create_visibility_table()
    local v_bf_csm1 = bgfx.create_dynamic_vertex_buffer(instance_num, declmgr.get("t47NIf").handle, "r")
    local v_bf_csm2 = bgfx.create_dynamic_vertex_buffer(instance_num, declmgr.get("t47NIf").handle, "r")
    local v_bf_csm3 = bgfx.create_dynamic_vertex_buffer(instance_num, declmgr.get("t47NIf").handle, "r")
    local v_bf_csm4 = bgfx.create_dynamic_vertex_buffer(instance_num, declmgr.get("t47NIf").handle, "r")
    local v_bf_pre_depth = bgfx.create_dynamic_vertex_buffer(instance_num, declmgr.get("t47NIf").handle, "r")
    local visibility_table = {
        ["csm1"] = v_bf_csm1, ["csm2"] = v_bf_csm2, ["csm3"] = v_bf_csm3, ["csm4"] = v_bf_csm4,
        ["pre_depth"] = v_bf_pre_depth
    }
    return visibility_table
end  

local function create_sm_dyb(sm_info, ro)
    sm_info.sm_visibility_table  = create_visibility_table()
    sm_info.instance_params = math3d.vector(0, ro.vb_num, 0, ro.ib_num)
    sm_info.indirect_params = math3d.vector(instance_num, 0, 0, 0)
    sm_info.dispatch_entity_table = {}
end

local function queue_select_sections_shadow(select_condition, queue_name)
    for e in w:select(select_condition) do
        local section_idx = e.section_index
        if sections_sm_table[section_idx] then
            for sm_idx, _ in pairs(sections_sm_table[section_idx].sms) do
                terrain_section_cull_table[queue_name].sms[sm_idx] = true
                local vidx = (sm_to_real_table[sm_idx] - 1) * 16 + 1
                for mesh_idx = 1, 4 do
                    constant_buffer_table.visibility_memory_table[mesh_idx][queue_name][vidx] = sm_table[sm_idx].mesh_visibility[mesh_idx]
                end
            end

            local ref_section_aabb = math3d.ref(sections_sm_table[section_idx].aabb)
            if not math3d.aabb_isvalid(terrain_section_cull_table[queue_name].aabb) then
                terrain_section_cull_table[queue_name].aabb = ref_section_aabb
            else
                if math3d.aabb_isvalid(ref_section_aabb) then
                    terrain_section_cull_table[queue_name].aabb = math3d.ref(math3d.aabb_merge(terrain_section_cull_table[queue_name].aabb, ref_section_aabb))
                end
            end 
        end
    end 
end

local function update_sm_dyb_table(mesh_idx, sm_info)
    update_sm_dyb(mesh_idx, "csm1", sm_info)
    update_sm_dyb(mesh_idx, "csm2", sm_info)
    update_sm_dyb(mesh_idx, "csm3", sm_info)
    update_sm_dyb(mesh_idx, "csm4", sm_info)
    update_sm_dyb(mesh_idx, "pre_depth", sm_info)
end

local function update_sections()
    terrain_section_cull_table = {
--[[         csm1 = {sections = {}, sms = {}, aabb = math3d.ref(math3d.aabb(mc.ZERO, mc.ZERO))},
        csm2 = {sections = {}, sms = {}, aabb = math3d.ref(math3d.aabb(mc.ZERO, mc.ZERO))},
        csm3 = {sections = {}, sms = {}, aabb = math3d.ref(math3d.aabb(mc.ZERO, mc.ZERO))},
        csm4 = {sections = {}, sms = {}, aabb = math3d.ref(math3d.aabb(mc.ZERO, mc.ZERO))},   ]] 
        pre_depth = {sections = {}, sms = {}, aabb = math3d.ref(math3d.aabb(mc.ZERO, mc.ZERO))}
    }
    for mesh_idx = 1, 4 do
        constant_buffer_table.visibility_memory_table[mesh_idx] = {
--[[             ["csm1"] = bgfx.memory_buffer(instance_num * 16),
            ["csm2"] = bgfx.memory_buffer(instance_num * 16),
            ["csm3"] = bgfx.memory_buffer(instance_num * 16),
            ["csm4"] = bgfx.memory_buffer(instance_num * 16), ]]
            ["pre_depth"] = bgfx.memory_buffer(instance_num * 16),
        }
    end
--[[     queue_select_sections_shadow("section_index:in csm1_queue_cull:absent", "csm1")
    queue_select_sections_shadow("section_index:in csm2_queue_cull:absent", "csm2")
    queue_select_sections_shadow("section_index:in csm3_queue_cull:absent", "csm3")
    queue_select_sections_shadow("section_index:in csm4_queue_cull:absent", "csm4") ]]
    queue_select_sections_shadow("section_index:in main_queue_cull:absent", "pre_depth")
end

local function create_constant_buffer()
    local function check_nan(v)
		if v ~= v then
			return 0
		else
			return v
		end
	end
	local function f2i(v)
		return math.floor(check_nan(v) * 32767+0.5)
	end
    constant_buffer_table.sm_srt_memory_buffer = bgfx.memory_buffer(16 * instance_num * 3)
    local fmt<const> = "ffff"
    for real_idx = 1, instance_num do
        local sm_idx = real_to_sm_table[real_idx]
        for size_idx = 1, 3 do
            local srt_idx = 16 * ((real_idx - 1) * 3 + size_idx - 1) + 1
            if sm_table[sm_idx][size_idx].s then
--[[                 local is = string.format("%.1f", sm_table[sm_idx][size_idx].s)+0
                local itx = string.format("%.1f", sm_table[sm_idx][size_idx].t.x)+0
                local itz = string.format("%.1f", sm_table[sm_idx][size_idx].t.z)+0
                local ir = string.format("%.1f", sm_table[sm_idx][size_idx].r)+0 ]]
                local stone = {sm_table[sm_idx][size_idx].s, sm_table[sm_idx][size_idx].t.x, sm_table[sm_idx][size_idx].t.z, sm_table[sm_idx][size_idx].r}
                --local stone = {is, itx, itz, ir}
                constant_buffer_table.sm_srt_memory_buffer[srt_idx] = fmt:pack(table.unpack(stone))
            else
                constant_buffer_table.sm_srt_memory_buffer[srt_idx] = fmt:pack(table.unpack({0, 0, 0, 0}))
            end
        end 
    end
    constant_buffer_table.sm_srt_buffer   = bgfx.create_dynamic_vertex_buffer(constant_buffer_table.sm_srt_memory_buffer, declmgr.get("t47NIf").handle, "r")
    constant_buffer_table.indirect_buffer_table = {
        bgfx.create_indirect_buffer(instance_num * 3),
        bgfx.create_indirect_buffer(instance_num * 3),
        bgfx.create_indirect_buffer(instance_num * 3),
        bgfx.create_indirect_buffer(instance_num * 3)
    }
    for mesh_idx = 1, 4 do
        constant_buffer_table.visibility_memory_table[mesh_idx] = {
--[[             ["csm1"] = bgfx.memory_buffer(instance_num * 16),
            ["csm2"] = bgfx.memory_buffer(instance_num * 16),
            ["csm3"] = bgfx.memory_buffer(instance_num * 16),
            ["csm4"] = bgfx.memory_buffer(instance_num * 16), ]]
            ["pre_depth"] = bgfx.memory_buffer(instance_num * 16),
        }
    end
end

local function make_sm_noise()
    get_center()
    get_count()
    get_map()
    get_scale()
    get_rotation()
    get_translation()
    get_real_sm()
    get_sections_sm()
    set_terrain_sm()
end

function sm_sys:init()
    sm_material = assetmgr.resource("/pkg/ant.resources/materials/stone_mountain/stone_mountain.material")
end

function sm_sys:stone_mountain()
    if open_sm then
        if not is_build_sm then
            is_build_sm = true
            for e in w:select "stonemountain sm_info?in bounding:update" do
                local sm_info = e.sm_info
                local center, extent = math3d.aabb_center_extents(e.bounding.aabb)
                mesh_aabb_table[sm_info.mesh_idx] = {center = math3d.tovalue(center), extent = math3d.tovalue(extent)}
                e.bounding.scene_aabb = mc.NULL
                e.bounding.aabb = mc.NULL
            end
            make_sm_noise()
            create_constant_buffer() 
        else
            update_sections()
            for e in w:select "stonemountain sm_info?update render_object?update" do
                local mesh_idx = e.sm_info.mesh_idx
                local ro = e.render_object
                local sm_info = e.sm_info
                local need_create_dyb = not e.sm_info.dispatch_entity_table
    
                if need_create_dyb then -- first create dynamic vertex buffer
                    create_sm_dyb(sm_info, ro)
                end
                update_sm_dyb_table(mesh_idx, sm_info)
                ro.idb_handle = constant_buffer_table.indirect_buffer_table[mesh_idx]
                ro.itb_handle = constant_buffer_table.sm_srt_buffer
                ro.draw_num   = instance_num * 3
            end
        end   
    end
end


