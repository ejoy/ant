local ecs   = ...
local world = ecs.world
local ww     = world.w

local iplane_terrain  = {}
local p_ts = ecs.system "plane_terrain_system"
local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr
local bgfx      = require "bgfx"
local math3d    = require "math3d"
local terrain_module = require "terrain"
local layout_name<const>    = declmgr.correct_layout "p3|t20|t42"
local layout                = declmgr.get(layout_name)
local noise1 = {}
local terrain_width, terrain_height, unit, origin_offset_width, origin_offset_height
local iom = ecs.require "ant.objcontroller|obj_motion"
local default_quad_ib<const> = {
    0, 1, 2,
    2, 3, 0,
}


local function noise(x, y, freq, exp, lb ,ub)
    local a = ub - lb
    local b = lb
    for iy = 1, y do
        for ix = 1, x do
            --t[#t + 1] = math3d.noise(ix - 1, iy - 1, freq, depth, seed) * 1
            local e1 = (terrain_module.noise(ix - 1, iy - 1, 1 * freq, 4, 0, 0, 0) * a + b) * 1
            local e2 = (terrain_module.noise(ix - 1, iy - 1, 2 * freq, 4, 0, 5.3, 9.1) * a + b) * 0.5
            local e3 = (terrain_module.noise(ix - 1, iy - 1, 4 * freq, 4, 0, 17.8, 23.5) * a + b) * 0.25
            --local e = (e1 + e2 + e3) / 1.75
            local e = e1
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

local packfmt<const> = "fffffffff"

local function get_terrain_uv(size, sectionx, sectiony)
    local uv_segment0 = {}
    local uv_segment1 = {}
    local uv_increment = 1 / size
    for idx = 1, size-1 do
        uv_segment0[idx] = idx * uv_increment
        uv_segment1[idx] = idx * uv_increment
    end
    uv_segment0[0] = 0
    uv_segment1[0] = 1
    local i1, i2, i3, i4 = (sectiony - 1) % size, (sectionx - 1) % size, sectiony % size, sectionx % size
    local u0, v0, u1, v1 = uv_segment0[i1], uv_segment0[i2], uv_segment1[i3], uv_segment1[i4]
    return u0, v0, u1, v1
end 

local function add_quad(vb, origin, extent, xx, yy, sand_color_idx, stone_color_idx)

    local ox, oy, oz = table.unpack(origin)
    local nx, ny, nz = ox + extent[1], oy + extent[2], oz + extent[3]
    --local u00, v00, u01, v01 = table.unpack(uv0)
    local u00, v00, u01, v01 = get_terrain_uv(8, xx, yy)
    --local u10, v10, u11, v11 = get_terrain_uv(32, xx, yy)
    local u10, v10, u11, v11 = get_terrain_uv(32, xx, yy)

    -- p3 position 
    -- t20 terrain_basecolor/terrain_height/terrain_normal 8x8
    -- t21 sand_alpha 32x32
    -- t22 v_sand_color_idx v_stone_color_idx(flat)
    local v = {
        packfmt:pack(ox, oy, oz, u00, v00, u10, v10, sand_color_idx, stone_color_idx),
        packfmt:pack(ox, oy, nz, u00, v01, u10, v11, sand_color_idx, stone_color_idx),
        packfmt:pack(nx, ny, nz, u01, v01, u11, v11, sand_color_idx, stone_color_idx),
        packfmt:pack(nx, ny, oz, u01, v00, u11, v10, sand_color_idx, stone_color_idx)            
    }  
    vb[#vb+1] = table.concat(v, "")
    
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
                -- other_uv sand_color_uv stone_color_uv sand_normal_uv stone_normal_uv sand_height_uv stone_height_uv
                local sand_color_idx = ((xx - 1) // 4) % 3
                local stone_color_idx = ((yy - 1) // 4) % 2 + 3
                --  add_quad(vb, origin, extent, uv0, uv1, xx, yy, rd, md, road_type, road_shape, mark_type, mark_shape, sand_color_idx, stone_color_idx, stone_normal_idx, width)
                add_quad(vb, origin, extent, xx, yy, sand_color_idx, stone_color_idx)
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

function iplane_terrain.get_wh()
    return terrain_width, terrain_height, unit, origin_offset_width
end

function iplane_terrain.init_plane_terrain(st, render_layer)
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
                            render_layer = render_layer,
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

function p_ts:init()
end

return iplane_terrain
