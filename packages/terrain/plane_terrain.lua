local ecs   = ...
local world = ecs.world
local ww     = world.w
local iplane_terrain  = ecs.interface "iplane_terrain"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local fs        = require "filesystem"
local datalist  = require "datalist"
local p_ts = ecs.system "plane_terrain_system"
local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr
local bgfx      = require "bgfx"
local math3d    = require "math3d"
local terrain_module = require "terrain"
local layout_name<const>    = declmgr.correct_layout "p3|t20|t21|t22|t23|t24|t25"
local layout                = declmgr.get(layout_name)
local noise1 = {}
local terrain_width, terrain_height, origin_offset_width, origin_offset_height
local default_quad_ib<const> = {
    0, 1, 2,
    2, 3, 0,
}

local function calc_tf_idx(iw, ih, w)
    return (ih - 1) * w + iw
end




local function noise(x, y, freq, exp, lb ,ub)
    local a = ub - lb
    local b = lb
    for iy = 1, y do
        for ix = 1, x do
            --t[#t + 1] = math3d.noise(ix - 1, iy - 1, freq, depth, seed) * 1
            local e1 = (terrain_module.noise(ix - 1, iy - 1, 1 * freq, 4, 0, 0, 0) * a + b) * 1
            local e2 = (terrain_module.noise(ix - 1, iy - 1, 2 * freq, 4, 0, 5.3, 9.1) * a + b) * 0.5
            local e3 = (terrain_module.noise(ix - 1, iy - 1, 4 * freq, 4, 0, 17.8, 23.5) * a + b) * 0.25
            local e = (e1 + e2 + e3) / 1.75
            noise1[#noise1 + 1] = e ^ exp
        end
    end
end


local terrainib_handle
local NUM_QUAD_VERTICES<const> = 4

--build ib
local function build_ib(width, height)
    --local MAX_TERRAIN<const> = 256 * 256
    local MAX_TERRAIN<const> = width * height
    do
        local terrainib = {}
        terrainib = default_quad_ib
        local fmt<const> = ('I'):rep(#terrainib)
        local offset<const> = NUM_QUAD_VERTICES
        local s = #fmt * 4


        local m = bgfx.memory_buffer(s * MAX_TERRAIN)
        for i=1, MAX_TERRAIN do
            local mo = s * (i - 1) + 1
            m[mo] = fmt:pack(table.unpack(terrainib))
            for ii = 1, #terrainib do
                terrainib[ii]  = terrainib[ii] + offset
            end
        end
        terrainib_handle = bgfx.create_index_buffer(m, "d")
    end
end


local function to_mesh_buffer(vb, aabb)
    local vbbin = table.concat(vb, "")
    local numv = #vbbin // layout.stride
    local numi = (numv // NUM_QUAD_VERTICES) * 6 --6 for one quad 2 triangles and 1 triangle for 3 indices

    return {
        bounding = {aabb = aabb and math3d.ref(aabb) or nil},
        vb = {
            start = 0,
            num = numv,
            handle = bgfx.create_vertex_buffer(bgfx.memory_buffer(vbbin), layout.handle),
        },
        ib = {
            start = 0,
            num = numi,
            handle = terrainib_handle,
        }
    }
end



local function is_edge_elem(iw, ih, w, h)
    if iw == 0 or ih == 0 or iw == w + 1 or ih == h + 1 then
        return false
    else
        return true
    end
end

local cterrain_fields = {}

function cterrain_fields.new(st)
    return setmetatable(st, {__index=cterrain_fields})
end

function cterrain_fields:init()
    local tf = self.prev_terrain_fields
    local width, height = self.width, self.height

    for ih = 1, height do
        for iw = 1, width do
            local idx = (ih - 1) * width + iw
            local f = tf[idx]
            local a_type, a_shape, a_dir
            if f.type == nil then
                a_dir = 1
            else
                a_type  = string.sub(f.type, 1, 1)
                f.alpha_type = a_type
                a_shape = string.sub(f.type, 2, 2)
                a_dir   = string.sub(f.type, 3, 3)
            end
            if a_shape == "U" then
                if f.alpha_type == "1" then
                    f.alpha_shape = 1
                else
                    f.alpha_shape = 8
                end
                if a_dir == "1" then
                    f.alpha_direction = 0
                elseif a_dir == "2" then
                    f.alpha_direction = 90
                elseif a_dir == "3" then
                    f.alpha_direction = 180
                elseif a_dir == "4" then
                    f.alpha_direction = 270
                end
            elseif a_shape == "I" then
                if f.alpha_type == "1" then
                    f.alpha_shape = 2
                else
                    f.alpha_shape = 10
                end
                if a_dir == "1" then
                    f.alpha_direction = 90
                elseif a_dir == "2" then
                    f.alpha_direction = 0
                    
                elseif a_dir == "3" then
                    f.alpha_direction = 270
                    
                elseif a_dir == "4" then
                    f.alpha_direction = 180
                end
            elseif a_shape == "L" then
                f.alpha_shape = 3
                if a_dir == "1" then
                    f.alpha_direction = 180
                elseif a_dir == "2" then
                    f.alpha_direction = 270
                elseif a_dir == "3" then
                    f.alpha_direction = 0
                elseif a_dir == "4" then
                    f.alpha_direction = 90
                end
            elseif a_shape == "T" then
                f.alpha_shape = 4
                if a_dir == "1" then
                    f.alpha_direction = 0
                elseif a_dir == "2" then
                    f.alpha_direction = 270
                elseif a_dir == "3" then
                    f.alpha_direction = 180
                elseif a_dir == "4" then
                    f.alpha_direction = 90
                end
            elseif a_shape == "X" then
                f.alpha_shape = 5
            elseif a_shape == 'O' then    
                if f.alpha_type == "1" then
                    f.alpha_shape = 7
                else
                    f.alpha_shape = 9
                end
            else
                f.alpha_shape = 6
            end                         
            
        end
    end
end

local packfmt<const> = "fffffffffffffff"

local function add_quad(vb, origin, extent, uv0, uv1, xx, yy, direction, road_type, road_shape, sand_color_idx, stone_color_idx, stone_normal_idx, width)
    local grid_type
    -- road_type ground/road/red/white
    if road_type == nil then
        grid_type = 0.0
    else
        grid_type = road_type
    end
    local ox, oy, oz = table.unpack(origin)
    local nx, ny, nz = ox + extent[1], oy + extent[2], oz + extent[3]
    local u00, v00, u01, v01 = table.unpack(uv0)
    local u10, v10, u11, v11 = table.unpack(uv1)
    local t = {
        [1] = 0.25,
        [2] = 0.50,
        [3] = 0.75,
    }
    local ii1 = (yy - 1) % 4
    local ii2 = (xx - 1) % 4
    local ii3 = (yy) % 4
    local ii4 = (xx) % 4

    local u20
    local v20
    local u21
    local v21

    if ii1 == 0 then
        u20 = 0
    else
        u20 = t[ii1]
    end

    if ii2 == 0 then
        v20 = 0
    else
        v20 = t[ii2]
    end

    if ii3 == 0 then
        u21 = 1
    else
        u21 = t[ii3]
    end

    if ii4 == 0 then
        v21 = 1
    else
        v21 = t[ii4]
    end

    --local u20, v20, u21, v21 = table.unpack(uv0)

    local i1 = calc_tf_idx(xx    ,     yy , width)
    local i2 = calc_tf_idx(xx + 1,     yy , width)
    local i3 = calc_tf_idx(xx + 1, yy + 1 , width)
    local i4 = calc_tf_idx(xx    , yy + 1 , width)
    local ns1, ns2, ns3, ns4 = noise1[i1], noise1[i2], noise1[i3], noise1[i4]

    if direction == 0 or direction == nil then
        local v = {
            packfmt:pack(ox, oy, oz, u00, v01, u10, v11, ns1, stone_normal_idx, grid_type, road_shape, sand_color_idx, stone_color_idx, u20, v20),
            packfmt:pack(ox, oy, nz, u00, v00, u10, v10, ns2, stone_normal_idx, grid_type, road_shape, sand_color_idx, stone_color_idx, u20, v21),
            packfmt:pack(nx, ny, nz, u01, v00, u11, v10, ns3, stone_normal_idx, grid_type, road_shape, sand_color_idx, stone_color_idx, u21, v21),
            packfmt:pack(nx, ny, oz, u01, v01, u11, v11, ns4, stone_normal_idx, grid_type, road_shape, sand_color_idx, stone_color_idx, u21, v20)            
        }
        vb[#vb+1] = table.concat(v, "")
    elseif direction == 90 then
        local v = {
            packfmt:pack(ox, oy, oz, u00, v01, u11, v11, ns1, stone_normal_idx, grid_type, road_shape, sand_color_idx, stone_color_idx, u20, v20),
            packfmt:pack(ox, oy, nz, u00, v00, u10, v11, ns2, stone_normal_idx, grid_type, road_shape, sand_color_idx, stone_color_idx, u20, v21),
            packfmt:pack(nx, ny, nz, u01, v00, u10, v10, ns3, stone_normal_idx, grid_type, road_shape, sand_color_idx, stone_color_idx, u21, v21),
            packfmt:pack(nx, ny, oz, u01, v01, u11, v10, ns4, stone_normal_idx, grid_type, road_shape, sand_color_idx, stone_color_idx, u21, v20) 
          
        }
        vb[#vb+1] = table.concat(v, "")
    elseif direction == 180 then
        local v = {
            packfmt:pack(ox, oy, oz, u00, v01, u11, v10, ns1, stone_normal_idx, grid_type, road_shape, sand_color_idx, stone_color_idx, u20, v20),
            packfmt:pack(ox, oy, nz, u00, v00, u11, v11, ns2, stone_normal_idx, grid_type, road_shape, sand_color_idx, stone_color_idx, u20, v21),
            packfmt:pack(nx, ny, nz, u01, v00, u10, v11, ns3, stone_normal_idx, grid_type, road_shape, sand_color_idx, stone_color_idx, u21, v21),
            packfmt:pack(nx, ny, oz, u01, v01, u10, v10, ns4, stone_normal_idx, grid_type, road_shape, sand_color_idx, stone_color_idx, u21, v20) 
          
        }
        vb[#vb+1] = table.concat(v, "")         
    elseif direction == 270 then
        local v = {
            packfmt:pack(ox, oy, oz, u00, v01, u10, v10, ns1, stone_normal_idx, grid_type, road_shape, sand_color_idx, stone_color_idx, u20, v20),
            packfmt:pack(ox, oy, nz, u00, v00, u11, v10, ns2, stone_normal_idx, grid_type, road_shape, sand_color_idx, stone_color_idx, u20, v21),
            packfmt:pack(nx, ny, nz, u01, v00, u11, v11, ns3, stone_normal_idx, grid_type, road_shape, sand_color_idx, stone_color_idx, u21, v21),
            packfmt:pack(nx, ny, oz, u01, v01, u10, v11, ns4, stone_normal_idx, grid_type, road_shape, sand_color_idx, stone_color_idx, u21, v20) 
          
        }
        vb[#vb+1] = table.concat(v, "")      
    end
    
end

function cterrain_fields:get_field(sidx, iw, ih)
    local ish = (sidx - 1) // self.section_width
    local isw = (sidx - 1) % self.section_width

    local offset = (ish * self.section_size+ih - 1) * self.width +
                    isw * self.section_size + iw
    local y = isw * self.section_size + iw
    local x = (ish * self.section_size+ih)
    return x, y, offset, self.prev_terrain_fields[offset]
end

function cterrain_fields:get_offset(sidx)
    local ish = (sidx-1) // self.section_width
    local isw = (sidx-1) % self.section_width
    return isw * self.section_size, ish * self.section_size
end

local function build_mesh(sectionsize, sectionidx, unit, cterrainfileds, width)
    local vb = {}
    for ih = 1, sectionsize do
        for iw = 1, sectionsize do
            local xx, yy, offset, field = cterrainfileds:get_field(sectionidx, iw, ih)
            if field ~= nil then
                local x, z = cterrainfileds:get_offset(sectionidx)
                local origin = {(iw - 1 + x) * unit - origin_offset_width * unit, 0.0, (ih - 1 + z) * unit - origin_offset_height * unit}
                local extent = {unit, 0, unit}
                local uv0 = {0.0, 0.0, 1.0, 1.0}
                -- other_uv sand_color_uv stone_color_uv sand_normal_uv stone_normal_uv sand_height_uv stone_height_uv
                local sand_color_idx = ((xx - 1) // 4) % 3
                local stone_color_idx = ((yy - 1) // 4) % 2 + 3
                local stone_normal_idx
                if stone_color_idx == 3 then
                    stone_normal_idx = 1
                else
                    stone_normal_idx = 2
                end
                local uv1 = uv0
                add_quad(vb, origin, extent, uv0, uv1, xx, yy, field.alpha_direction, field.alpha_type, field.alpha_shape - 1, sand_color_idx, stone_color_idx, stone_normal_idx, width)
            end
        end
    end

    if #vb > 0 then
        local min_x, min_z = cterrainfileds:get_offset(sectionidx)
        local max_x, max_z = min_x + sectionsize, min_z + sectionsize

        --minv = ((min_x, 0, min_z) - (origin_offset_width, 0, origin_offset_height)) * unit
        --maxv = ((max_x, 0, max_z) - (origin_offset_width, 0, origin_offset_height)) * unit
        local offset = math3d.vector(-origin_offset_width*unit, 0, -origin_offset_height*unit)
        return to_mesh_buffer(vb, math3d.aabb(
            math3d.muladd(math3d.vector(min_x, 0, min_z), unit, offset),
            math3d.muladd(math3d.vector(max_x, 0, max_z), unit, offset)))
    end
end

local function is_power_of_2(n)
	if n ~= 0 then
		local l = math.log(n, 2)
		return math.ceil(l) == math.floor(l)
	end
end

function iplane_terrain.set_wh(w, h, offset_x, offset_z)
    terrain_width = w
    terrain_height = h
    if offset_x == nil then
        origin_offset_width = 0
    else
        origin_offset_width = offset_x
    end

    if offset_z == nil then
        origin_offset_height = 0
    else
        origin_offset_height = offset_z
    end

    build_ib(terrain_width, terrain_height)
    noise(terrain_width + 1, terrain_height + 1, 4, 2, 0.2, 1)
end

function iplane_terrain.init_plane_terrain(st)
    if st.prev_terrain_fields == nil then
        error "need define terrain_field, it should be file or table"
    end

    local width, height = st.width, st.height

    local ss = st.section_size


    st.section_width, st.section_height = width // ss, height // ss
    st.num_section = st.section_width * st.section_height

    local unit = st.unit
    local shapematerial = st.material
    
    --build_ib(width,height)
    local ctf = cterrain_fields.new(st)
    ctf:init()
    
    for ih = 1, st.section_height do
        for iw = 1, st.section_width do
            local sectionidx = (ih - 1) * st.section_width + iw
            
            local terrain_mesh = build_mesh(ss, sectionidx, unit, ctf, width)
            if terrain_mesh then
                local eid; eid = ecs.create_entity{
                    policy = {
                        "ant.scene|scene_object",
                        "ant.render|simplerender",
                        "ant.general|name",
                    },
                    data = {
                        scene = {
                            --parent = e.eid,
                        },
                        simplemesh  = terrain_mesh,
                        material    = shapematerial,
                        visible_state= "main_view|selectable",
                        name        = "section" .. sectionidx,
                        plane_terrain = true,
                        section_index = sectionidx,
                        on_ready = function()
                            --world:pub {"shape_terrain", "on_ready", eid, e.eid}
                        end,
                    },
                }
            end
        end
    end   
end


function iplane_terrain.update_plane_terrain(st, tc)
        if st.prev_terrain_fields == nil then
            error "need define terrain_field, it should be file or table"
        end

        local width, height = st.width, st.height

        local ss = st.section_size


        st.section_width, st.section_height = width // ss, height // ss
        st.num_section = st.section_width * st.section_height

        local unit = st.unit
        local shapematerial = st.material
        
        --build_ib(width,height)
        local ctf = cterrain_fields.new(st)
        ctf:init()
        
        for section_idx,_ in pairs(tc) do
            local terrain_mesh = build_mesh(ss, section_idx, unit, ctf, width)
            if terrain_mesh then
                local eid; eid = ecs.create_entity{
                    policy = {
                        "ant.scene|scene_object",
                        "ant.render|simplerender",
                        "ant.general|name",
                    },
                    data = {
                        scene = {
                            --parent = e.eid,
                        },
                        simplemesh  = terrain_mesh,
                        material    = shapematerial,
                        visible_state= "main_view|selectable",
                        name        = "section" .. section_idx,
                        plane_terrain = true,
                        section_index = section_idx,
                        on_ready = function()
                            --world:pub {"shape_terrain", "on_ready", eid, e.eid}
                        end,
                    },
                }
            end    
        end  
end

function p_ts:init()


end