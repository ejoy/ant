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
local layout_name<const>    = declmgr.correct_layout "p3|t20|t21|t22|t23|t24|t25|t26|t27"
local layout                = declmgr.get(layout_name)
local noise1 = {}
local terrain_width, terrain_height, unit, origin_offset_width, origin_offset_height
local iom = ecs.import.interface "ant.objcontroller|iobj_motion"
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

local cterrain_fields = {}

function cterrain_fields.new(st)
    return setmetatable(st, {__index=cterrain_fields})
end

local function parse_layer(t, s, d)
    local pt, ps, pd
    if s == "U" then
        ps = 1 -- road 4 + 1 / mark 1
        if d == "1" then
            pd = 0
        elseif d == "2" then
            pd = 90
        elseif d == "3" then
            pd = 180
        elseif d == "4" then
            pd = 270
        end
    elseif s == "I" then
        if t >= "1" and t <= "3" then
            ps = 2 -- road 4 + 2
        else
            ps = 3 -- mark 3
        end
        if d == "1" then
            pd = 90
        elseif d == "2" then
            pd = 0   
        elseif d == "3" then
            pd = 270
        elseif d == "4" then
            pd = 180
        end
    elseif s == "L" then
        if t >= "1" and t <= "3" then
            ps = 3 
        else
            ps = 5
        end
        if d == "1" then
            pd = 180
        elseif d == "2" then
            pd = 270
        elseif d == "3" then
            pd = 0
        elseif d == "4" then
            pd = 90
        end
    elseif s == "T" then
        if t >= "1" and t <= "3" then
            ps = 4 
        else
            ps = 6
        end
        if d == "1" then
            pd = 0
        elseif d == "2" then
            pd = 90
        elseif d == "3" then
            pd = 180
        elseif d == "4" then
            pd = 270
        end
    elseif s == "X" then
        if t >= "1" and t <= "3" then
            ps = 5  -- road 4 + 5
        else
            ps = 4 -- mark 4
        end
    elseif s == 'O' then    
        if t >= "1" and t <= "3" then
            ps = 7  -- road 4 + 7
        else
            ps = 2 -- mark 2
        end
    else
        if t >= "1" and t <= "3" then
            ps = 6  -- road 4 + 6
        else
            ps = 5 -- mark 5
        end
    end
    pt = t
    return pt, ps, pd                          
end

function cterrain_fields:init()
    local tf = self.prev_terrain_fields
    local width, height = self.width, self.height

    for ih = 1, height do
        for iw = 1, width do
            local idx = (ih - 1) * width + iw
            local f = tf[idx]
            local layers = f.layers

            if layers == nil then
                f.road_type = 0.0
                f.road_direction = 0.0
                f.road_shape = 0.0
                f.mark_type  = 0.0
                f.mark_direction = 0.0
                f.mark_shape = 0.0
            else
                for i, layer in pairs(layers) do
                    local t, s, d
                    t = string.sub(layer, 1, 1)
                    s = string.sub(layer, 2, 2)
                    d = string.sub(layer, 3, 3)
                    local pt, ps, pd = parse_layer(t, s, d)
                    if i == 1 then
                        f["road_type"] = pt
                        f["road_direction"] = pd
                        f["road_shape"] = ps
                    elseif i == 2 then
                        f["mark_type"] = pt
                        f["mark_direction"] = pd
                        f["mark_shape"] = ps
                    end
                end
            end  
            
            if layers and layers[1] == nil then
                f.road_type = 0.0
                f.road_direction = 0.0
                f.road_shape = 0.0
            elseif layers and layers[2] == nil then
                f.mark_type  = 0.0
                f.mark_direction = 0.0
                f.mark_shape = 0.0
            elseif layers and layers[1] == nil and layers[2] == nil then
                f.road_type = 0.0
                f.road_direction = 0.0
                f.road_shape = 0.0
                f.mark_type  = 0.0
                f.mark_direction = 0.0
                f.mark_shape = 0.0                                        
            end
        end
    end
end

local packfmt<const> = "fffffffffffffffffff"

local direction_table ={
    [0]   = {0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0},
    [90]  = {1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0},
    [180] = {1.0, 0.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0},
    [270] = {0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0}
}

local function get_vb(rd, rd_idx, md, md_idx)
    local t1x, t1y, t7x, t7y
    if rd == nil then
        t1x, t1y = direction_table[0][rd_idx * 2 + 1], direction_table[0][rd_idx * 2 + 2]
    else
        t1x, t1y = direction_table[rd][rd_idx * 2 + 1], direction_table[rd][rd_idx * 2 + 2]
    end
    if md == nil then
        t7x, t7y = direction_table[0][md_idx * 2 + 1], direction_table[0][md_idx * 2 + 2]
    else
        t7x, t7y = direction_table[md][md_idx * 2 + 1], direction_table[md][md_idx * 2 + 2]
    end
    return t1x, t1y, t7x, t7y
end

local function add_quad(vb, origin, extent, uv0, uv1, xx, yy, rd, md, rtype, road_shape, mtype, mark_shape, sand_color_idx, stone_color_idx, stone_normal_idx, width)
    local road_type, mark_type
    -- road_type ground/road/red/white
    if not rtype or rtype == 0 then
        road_type = 0
    else
        road_type = rtype
    end
    if not mtype or mtype == 0 then
        mark_type = 0
    else
        mark_type = mtype - 3
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
    -- p3 position 
    -- t20 road_height 
    -- t21 road_road 
    -- t22 terrain_color/road_color/terrain_height
    -- t23 v_sand_road v_stone_normal_idx
    -- t24 v_road_type v_road_shape(flat)
    -- t25 v_sand_color_idx v_stone_color_idx(flat)
    -- t26 v_mark_type v_mark_shape
    -- t27 mark_road
    local t1x0, t1y0, t7x0, t7y0 = get_vb(rd, 0, md, 0)
    local t1x1, t1y1, t7x1, t7y1 = get_vb(rd, 1, md, 1)
    local t1x2, t1y2, t7x2, t7y2 = get_vb(rd, 2, md, 2)
    local t1x3, t1y3, t7x3, t7y3 = get_vb(rd, 3, md, 3)
    local v = {
        packfmt:pack(ox, oy, oz, u00, v01, t1x0, t1y0, u20, v20, ns1, stone_normal_idx, road_type, road_shape, sand_color_idx, stone_color_idx, mark_type, mark_shape, t7x0, t7y0),
        packfmt:pack(ox, oy, nz, u00, v00, t1x1, t1y1, u20, v21, ns2, stone_normal_idx, road_type, road_shape, sand_color_idx, stone_color_idx, mark_type, mark_shape, t7x1, t7y1),
        packfmt:pack(nx, ny, nz, u01, v00, t1x2, t1y2, u21, v21, ns3, stone_normal_idx, road_type, road_shape, sand_color_idx, stone_color_idx, mark_type, mark_shape, t7x2, t7y2),
        packfmt:pack(nx, ny, oz, u01, v01, t1x3, t1y3, u21, v20, ns4, stone_normal_idx, road_type, road_shape, sand_color_idx, stone_color_idx, mark_type, mark_shape, t7x3, t7y3)            
    }
    vb[#vb+1] = table.concat(v, "")
   --[[  if direction == 0 or direction == nil then
        local v = {
            packfmt:pack(ox, oy, oz, u00, v01, u10, v11, u20, v20, ns1, stone_normal_idx, road_type, road_shape, sand_color_idx, stone_color_idx),
            packfmt:pack(ox, oy, nz, u00, v00, u10, v10, u20, v21, ns2, stone_normal_idx, road_type, road_shape, sand_color_idx, stone_color_idx),
            packfmt:pack(nx, ny, nz, u01, v00, u11, v10, u21, v21, ns3, stone_normal_idx, road_type, road_shape, sand_color_idx, stone_color_idx),
            packfmt:pack(nx, ny, oz, u01, v01, u11, v11, u21, v20, ns4, stone_normal_idx, road_type, road_shape, sand_color_idx, stone_color_idx)            
        }
        vb[#vb+1] = table.concat(v, "")
    elseif direction == 90 then
        local v = {
            packfmt:pack(ox, oy, oz, u00, v01, u11, v11, u20, v20, ns1, stone_normal_idx, road_type, road_shape, sand_color_idx, stone_color_idx),
            packfmt:pack(ox, oy, nz, u00, v00, u10, v11, u20, v21, ns2, stone_normal_idx, road_type, road_shape, sand_color_idx, stone_color_idx),
            packfmt:pack(nx, ny, nz, u01, v00, u10, v10, u21, v21, ns3, stone_normal_idx, road_type, road_shape, sand_color_idx, stone_color_idx),
            packfmt:pack(nx, ny, oz, u01, v01, u11, v10, u21, v20, ns4, stone_normal_idx, road_type, road_shape, sand_color_idx, stone_color_idx) 
          
        }
        vb[#vb+1] = table.concat(v, "")
    elseif direction == 180 then
        local v = {
            packfmt:pack(ox, oy, oz, u00, v01, u11, v10, u20, v20, ns1, stone_normal_idx, road_type, road_shape, sand_color_idx, stone_color_idx),
            packfmt:pack(ox, oy, nz, u00, v00, u11, v11, u20, v21, ns2, stone_normal_idx, road_type, road_shape, sand_color_idx, stone_color_idx),
            packfmt:pack(nx, ny, nz, u01, v00, u10, v11, u21, v21, ns3, stone_normal_idx, road_type, road_shape, sand_color_idx, stone_color_idx),
            packfmt:pack(nx, ny, oz, u01, v01, u10, v10, u21, v20, ns4, stone_normal_idx, road_type, road_shape, sand_color_idx, stone_color_idx) 
          
        }
        vb[#vb+1] = table.concat(v, "")         
    elseif direction == 270 then
        local v = {
            packfmt:pack(ox, oy, oz, u00, v01, u10, v10, u20, v20, ns1, stone_normal_idx, road_type, road_shape, sand_color_idx, stone_color_idx),
            packfmt:pack(ox, oy, nz, u00, v00, u11, v10, u20, v21, ns2, stone_normal_idx, road_type, road_shape, sand_color_idx, stone_color_idx),
            packfmt:pack(nx, ny, nz, u01, v00, u11, v11, u21, v21, ns3, stone_normal_idx, road_type, road_shape, sand_color_idx, stone_color_idx),
            packfmt:pack(nx, ny, oz, u01, v01, u10, v11, u21, v20, ns4, stone_normal_idx, road_type, road_shape, sand_color_idx, stone_color_idx) 
          
        }
        vb[#vb+1] = table.concat(v, "")      
    end ]]
    
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

local function build_mesh(sectionsize, sectionidx, cterrainfileds, width)
    local vb = {}
    for ih = 1, sectionsize do
        for iw = 1, sectionsize do
            local xx, yy, offset, field = cterrainfileds:get_field(sectionidx, iw, ih)
            if field ~= nil then
                local x, z = cterrainfileds:get_offset(sectionidx)
                local origin = {(iw - 1 + x) * unit, 0.0, (ih - 1 + z) * unit}
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
                --  add_quad(vb, origin, extent, uv0, uv1, xx, yy, rd, md, road_type, road_shape, mark_type, mark_shape, sand_color_idx, stone_color_idx, stone_normal_idx, width)
                add_quad(vb, origin, extent, uv0, uv1, xx, yy, field.road_direction, field.mark_direction, field.road_type, field.road_shape, field.mark_type, field.mark_shape, sand_color_idx, stone_color_idx, stone_normal_idx, width)
            end
        end
    end

    if #vb > 0 then
        local min_x, min_z = cterrainfileds:get_offset(sectionidx)
        local max_x, max_z = min_x + sectionsize, min_z + sectionsize

        return to_mesh_buffer(vb, math3d.aabb(
            math3d.mul(math3d.vector(min_x, 0, min_z), unit),
            math3d.mul(math3d.vector(max_x, 0, max_z), unit)))
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
    for e in ww:select "shape_terrain st:update eid:in" do
        e.st = st
        if st.prev_terrain_fields == nil then
            error "need define terrain_field, it should be file or table"
        end

        local width, height = st.width, st.height

        local ss = st.section_size


        st.section_width, st.section_height = width // ss, height // ss
        st.num_section = st.section_width * st.section_height

        unit = st.unit
        local shapematerial = st.material
        
        --build_ib(width,height)
        local ctf = cterrain_fields.new(st)
        ctf:init()
        
        for ih = 1, st.section_height do
            for iw = 1, st.section_width do
                local sectionidx = (ih - 1) * st.section_width + iw
                
                local terrain_mesh = build_mesh(ss, sectionidx, ctf, width)
                if terrain_mesh then
                    local eid; eid = ecs.create_entity{
                        policy = {
                            "ant.scene|scene_object",
                            "ant.render|simplerender",
                            "ant.general|name",
                        },
                        data = {
                            scene = {
                                parent = e.eid,
                            },
                            simplemesh  = terrain_mesh,
                            material    = shapematerial,
                            visible_state= "main_view|selectable",
                            name        = "section" .. sectionidx,
                            plane_terrain = true,
                            section_index = sectionidx,
                            on_ready = function()
                                world:pub {"shape_terrain", "on_ready", eid, e.eid}
                            end,
                        },
                    }
                end
            end
        end
        iom.set_position(e, math3d.vector(-origin_offset_width * unit, 0, -origin_offset_height * unit))
    end   
end


function iplane_terrain.update_plane_terrain(tc)
    
    for e in ww:select "shape_terrain st:update eid:in" do
        local st = e.st
        if st.prev_terrain_fields == nil then
            error "need define terrain_field, it should be file or table"
        end

        local width, height = st.width, st.height

        local ss = st.section_size


        st.section_width, st.section_height = width // ss, height // ss
        st.num_section = st.section_width * st.section_height

        local shapematerial = st.material
        
        --build_ib(width,height)
        local ctf = cterrain_fields.new(st)
        ctf:init()
        
        for section_idx,_ in pairs(tc) do
            local terrain_mesh = build_mesh(ss, section_idx, ctf, width)
            if terrain_mesh then
                local eid; eid = ecs.create_entity{
                    policy = {
                        "ant.scene|scene_object",
                        "ant.render|simplerender",
                        "ant.general|name",
                    },
                    data = {
                        scene = {
                            parent = e.eid,
                        },
                        simplemesh  = terrain_mesh,
                        material    = shapematerial,
                        visible_state= "main_view|selectable",
                        name        = "section" .. section_idx,
                        plane_terrain = true,
                        section_index = section_idx,
                        on_ready = function()
                            world:pub {"shape_terrain", "on_ready", eid, e.eid}
                        end,
                    },
                }
            end    
        end
        iom.set_position(e, math3d.vector(-origin_offset_width * unit, 0, -origin_offset_height * unit))
    end
end

function p_ts:init()


end