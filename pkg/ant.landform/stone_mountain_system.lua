local ecs = ...
local world = ecs.world
local w = world.w
local fastio    = require "fastio"
local datalist  = require "datalist"
local math3d 	= require "math3d"
local bgfx 		= require "bgfx"
local idrawindirect = ecs.require "ant.render|draw_indirect_system"
local imaterial     = ecs.require "ant.asset|material"
local layoutmgr = import_package "ant.render".layoutmgr
local assetmgr  = import_package "ant.asset"
local terrain_module = require "terrain"
local ism = {}
local sm_sys = ecs.system "stone_mountain_system"
local mc     = import_package "ant.math".constant
local open_sm = false
local vb_num, vb_size, vb2_size, ib_num, ib_size = 0, 0, 0, 0, 0
local vb_handle, vb2_handle, ib_handle
local sm_table = {}
local aabb_table = {
    math3d.ref(math3d.aabb(math3d.vector(-33.2579,-0.0005,-32.6542,0.0), math3d.vector(35.1511,45.1606,31.0777,0.0))),
    math3d.ref(math3d.aabb(math3d.vector(-26.2541,0.0,-20.8443,0.0), math3d.vector(17.2726,42.8129,21.9373,0.0))),
    math3d.ref(math3d.aabb(math3d.vector(-24.6474,0.0,-27.0006,0.0), math3d.vector(20.777,41.7251,30.2341,0.0))),
    math3d.ref(math3d.aabb(math3d.vector(-22.9146,-0.0,-24.5635,0.0), math3d.vector(27.4767,44.5719,28.3179,0.0)))
}
local mesh_idx_table = {}
local ratio, width, height = 0.80, 256, 256
local ratio_table = {
    0.88, 0.90, 0.92, 0.94
}
local freq, depth, unit, offset = 4, 4, 10, 0
local mesh_table = {
    {filename = "/pkg/ant.landform/assets/meshes/mountain1.glb|meshes/Cylinder.002_P1.meshbin"},
    {filename = "/pkg/ant.landform/assets/meshes/mountain2.glb|meshes/Cylinder.004_P1.meshbin"},
    {filename = "/pkg/ant.landform/assets/meshes/mountain3.glb|meshes/Cylinder_P1.meshbin"},
    {filename = "/pkg/ant.landform/assets/meshes/mountain4.glb|meshes/Cylinder.021_P1.meshbin"}
}

local sm_info_table = {
    {sidx = 1, scale = {lb = 0.064, rb = 0.064}, offset = 0.5}, 
    {sidx = 2, scale = {lb = 0.064, rb = 0.200}, offset = 0.1}, 
    {sidx = 3, scale = {lb = 0.125, rb = 0.250}, offset = 1.5},
    {sidx = 4, scale = {lb = 0.350, rb = 0.250}, offset = 2.0}
}


local function generate_sm_config()
    local function update_idx_table(x, z, m, n, idx_table)
        for oz = 0, n - 1 do
            for ox = 0, m - 1 do
                local xx, zz = ox + x, oz + z
                local idx = 1 + zz * width + xx
                if xx < width and zz < height then
                    idx_table[idx] = 1
                end
            end
        end        
    end
    local idx_table = {}
    for iz = 0, height - 1 do
        for ix = 0, width - 1 do
            for ri = 1, 4 do
                local seed, offset_y, offset_x = iz * ix + ri, iz + ri, ix + ri
                local noise = terrain_module.noise(ix, iz, freq, depth, seed, offset_y, offset_x)
                if ri == 1 then -- 1x1
                    local idx = 1 + iz * width + ix
                    if noise > ratio_table[ri] then
                        idx_table[idx] = 1
                    elseif not idx_table[idx] then
                        
                        idx_table[idx] = 0
                    end
                else
                    if noise > ratio_table[ri] then
                        update_idx_table(ix, iz, ri, ri, idx_table)
                    end   
                end
            end
        end
    end
    return string.pack(("B"):rep(width * height), table.unpack(idx_table))
end

function ism.create_random_sm(d, ww, hh, off, un)
    ratio = ratio + (1 - d) / 10
    width, height =  ww, hh
    if off then offset = off end
    if un then unit = un end
    return generate_sm_config()
end

function ism.create_sm_entity(group_table)
    open_sm = true
    for iz = 0, height - 1 do
        for ix = 0, width - 1 do
            local idx = iz * width + ix + 1
            local sm_group = group_table[idx]
            if sm_group then
                local sm_idx = (iz << 16) + ix
                sm_table[sm_idx] = {}
            end
        end
    end
end

local function get_srt()
    for _, sm_info in pairs(sm_info_table) do
        local sidx, lb, rb, off = sm_info.sidx, sm_info.scale.lb, sm_info.scale.rb, sm_info.offset
        for sm_idx, _ in pairs(sm_table) do
            if sm_table[sm_idx][sidx] then
                local ix, iz = sm_idx & 65535, sm_idx >> 16
                local seed, offset_y, offset_x = iz * ix + sidx, iz + sidx, ix + sidx
                local s_noise = terrain_module.noise(ix, iz, freq, depth, seed, offset_y, offset_x) * rb + lb
                local r_noise = math.floor(terrain_module.noise(ix, iz, freq, depth, seed, offset_y, offset_x) * 360) + math.random(-360, 360) 
                local mesh_noise = (sm_idx + math.random(0, 4)) % 4 + 1
                local tx, tz = (ix + off - offset) * unit, (iz + off - offset) * unit
                sm_table[sm_idx][sidx] = {s = s_noise, r = r_noise, tx = tx, tz = tz, m = mesh_noise}
            end
        end
    end
end

local function set_sm_property()
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

    for sm_idx, _ in pairs(sm_table) do
        local ix, iz = sm_idx & 65535, sm_idx >> 16
        local near_table = {[1] = true}
        for _ , sm_info in pairs(sm_info_table) do
            local sidx = sm_info.sidx
            if sidx ~= 1 and has_block(ix, iz, sidx, sidx) then
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

local function make_sm_noise()
    set_sm_property()
    get_srt()
end

local function load_mem(m, filename)
    local function parent_path(v)
        return v:match("^(.+)/[^/]*$")
    end
    local binname = m[1]
    assert(type(binname) == "string" and (binname:match "%.[iv]bbin" or binname:match "%.[iv]b[2]bin"))

    local data, err = fastio.readall_s(assetmgr.compile(parent_path(filename) .. "/" .. binname))
    if not data then
        error(("read file failed:%s, error:%s"):format(binname, err))
    end
    m[1] = data
end

function sm_sys:init()
    local vb_memory, vb2_memory, ib_memory = '', '', ''
    local vb_decl, vb2_decl = layoutmgr.get('p30NIf|T40nii').handle, layoutmgr.get('c40niu|t20NIf').handle
    for idx = 1, 4 do
        local mesh = mesh_table[idx]
        local local_filename = assetmgr.compile(mesh.filename)
        local mm = datalist.parse(fastio.readall_s(local_filename))
        load_mem(mm.vb.memory,  mesh.filename)
        load_mem(mm.vb2.memory, mesh.filename)
        load_mem(mm.ib.memory,  mesh.filename)
        vb_num, vb_size, vb2_size = vb_num + mm.vb.num, vb_size + mm.vb.memory[3], vb2_size + mm.vb2.memory[3]
        ib_num, ib_size = ib_num + mm.ib.num, ib_size + mm.ib.memory[3]
        mesh.vb_num, mesh.vb_size, mesh.vb2_size = mm.vb.num, mm.vb.memory[3], mm.vb2.memory[3]
        mesh.ib_num, mesh.ib_size = mm.ib.num, mm.ib.memory[3]
        vb_memory  = vb_memory .. mm.vb.memory[1]
        vb2_memory = vb2_memory .. mm.vb2.memory[1]
        ib_memory  = ib_memory .. mm.ib.memory[1]
    end
    vb_handle  = bgfx.create_vertex_buffer(bgfx.memory_buffer(table.unpack{vb_memory, 1, vb_size}), vb_decl)
    vb2_handle = bgfx.create_vertex_buffer(bgfx.memory_buffer(table.unpack{vb2_memory, 1, vb2_size}), vb2_decl)
    ib_handle  = bgfx.create_index_buffer(bgfx.memory_buffer(table.unpack{ib_memory, 1, ib_size}), '')
end

local function update_ro(ro)
    ro.vb_handle, ro.vb2_handle, ro.ib_handle = vb_handle, vb2_handle, ib_handle
    ro.vb_num, ro.vb2_num, ro.ib_num = vb_num, vb_num, ib_num
end

local function get_indirect_params()
    local indirect_params_table = {}
    local vb_offset, ib_offset = 0, 0
    for mesh_idx = 1, #mesh_table do
        local ib_num = mesh_table[mesh_idx].ib_num
        if mesh_idx ~= 1 then
            local prev_mesh = mesh_table[mesh_idx-1]
            vb_offset, ib_offset = vb_offset + prev_mesh.vb_num, ib_offset + prev_mesh.ib_num
        end
        indirect_params_table[mesh_idx] = math3d.vector(vb_offset, ib_offset, ib_num, 0)
    end
    return indirect_params_table
end



function sm_sys:entity_init()

    for e in w:select "INIT stonemountain:update render_object?update eid:in" do
        local stonemountain = e.stonemountain
        update_ro(e.render_object)
        local max_num = 5000
        local draw_indirect_eid = world:create_entity {
            policy = {
                "ant.render|draw_indirect"
            },
            data = {
                draw_indirect = {
                    target_eid = e.eid,
                    itb_flag = "r",
                    aabb_table = aabb_table,
                    mesh_idx_table = mesh_idx_table,
                    srt_table = stonemountain.srt_info,
                    draw_num = stonemountain.draw_num,
                    max_num = max_num,
                    indirect_params_table = get_indirect_params(),
                    indirect_type = "stone_mountain"
                },
            }
        }
        stonemountain.draw_indirect_eid = draw_indirect_eid
        e.render_object.draw_num = 0
        e.render_object.idb_handle = 0xffffffff
        e.render_object.itb_handle = 0xffffffff
    end

    
    for e in w:select "stonemountain:update render_object:update scene:in bounding:update draw_indirect_ready:out" do
        local stonemountain = e.stonemountain
        local draw_num = stonemountain.draw_num
        if draw_num > 0 then
            local de <close> = world:entity(stonemountain.draw_indirect_eid, "draw_indirect:in")
            local idb_handle, itb_handle = de.draw_indirect.idb_handle, de.draw_indirect.itb_handle
            e.render_object.idb_handle = idb_handle
            e.render_object.itb_handle = itb_handle
            e.render_object.draw_num = draw_num
        else
            e.render_object.idb_handle = 0xffffffff
            e.render_object.itb_handle = 0xffffffff
            e.render_object.draw_num = 0
        end

        e.draw_indirect_ready = false
    end
end

local function create_sm_entity()
    --TODO
    if true then return end
    local stonemountain = {draw_num = 0, srt_info = {}}

    for _, sms in pairs(sm_table) do
        for _, sm in pairs(sms) do
            local mesh_idx = sm.m
            mesh_idx_table[#mesh_idx_table+1] = math3d.vector(0, 0, 0, mesh_idx)
            stonemountain.draw_num = stonemountain.draw_num + 1
            stonemountain.srt_info[#stonemountain.srt_info+1] = {
                math3d.vector(sm.s, sm.r, sm.tx, sm.tz),
                math3d.vector(0, 0, 0, 0),
                math3d.vector(0, 0, 0, 0)
            } 
        end
    end
    world:create_entity {
        policy = {
            "ant.render|render",
            "ant.landform|stonemountain",
            "ant.render|indirect"
         },
        data = {
            scene         = {},
            mesh =  mesh_table[1].filename,
            material      ="/pkg/ant.landform/assets/materials/pbr_sm.material", 
            visible_state = "main_view|cast_shadow",
            stonemountain = stonemountain,
            draw_indirect_ready = false,
            render_layer = "foreground",
            indirect = "STONE_MOUNTAIN",
            on_ready = function(e)
                local draw_indirect_type = idrawindirect.get_draw_indirect_type("STONE_MOUNTAIN")
                imaterial.set_property(e, "u_draw_indirect_type", math3d.vector(draw_indirect_type))
            end
        }
    }
end

function sm_sys:stone_mountain()
    if open_sm then
        make_sm_noise()
        create_sm_entity()
        open_sm = false
    end
end

function sm_sys:entity_remove()
    for e in w:select "REMOVED stonemountain:in" do
        w:remove(e.stonemountain.draw_indirect_eid)
    end
end

function sm_sys:data_changed()

end

return ism
