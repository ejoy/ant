local ecs   = ...
local world = ecs.world
local ww     = world.w
local imaterial = ecs.import.interface "ant.asset|imaterial"
local fs        = require "filesystem"
local datalist  = require "datalist"
local p_ts = ecs.system "plane_terrain_system"
local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr
local bgfx      = require "bgfx"
local math3d    = require "math3d"
local terrain_module = require "terrain"
local layout_name<const>    = declmgr.correct_layout "p4|t20|t21"
local layout                = declmgr.get(layout_name)

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
    local t = {}
    for iy = 1, y do
        for ix = 1, x do
            --t[#t + 1] = math3d.noise(ix - 1, iy - 1, freq, depth, seed) * 1
            local e1 = (terrain_module.noise(ix - 1, iy - 1, 1 * freq, 4, 0, 0, 0) * a + b) * 1
            local e2 = (terrain_module.noise(ix - 1, iy - 1, 2 * freq, 4, 0, 5.3, 9.1) * a + b) * 0.5
            local e3 = (terrain_module.noise(ix - 1, iy - 1, 4 * freq, 4, 0, 17.8, 23.5) * a + b) * 0.25
            local e = (e1 + e2 + e3) / 1.75
            t[#t + 1] = e ^ exp
        end
    end
    return t
end

--build ib
local terrainib_handle
--local MAX_TERRAIN<const> = 256 * 256
local MAX_TERRAIN<const> = 8 * 8
local NUM_QUAD_VERTICES<const> = 4
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



local function is_edge_elem(iw, ih, w, h, ftype, tf)
    if iw == 0 or ih == 0 or iw == w + 1 or ih == h + 1 then
        if ftype == "d" then
            return false
        elseif ftype == "g" then
            return true
        end
    elseif tf[calc_tf_idx(iw, ih, w)].type ~= ftype then
        return true
    else
        return false
    end
end

local function check_neighbour_elems(iw, ih, w, h, tf, ftype)
    local neighbour_8 = {}
    local neighbour_4 = {}
    local len_8 = 0
    local len_4 = 0
    if is_edge_elem(iw - 1, ih - 1, w, h, ftype, tf) then
        neighbour_8.lt = true;
        len_8 = len_8 + 1
    end
    if is_edge_elem(iw + 1, ih - 1, w, h, ftype, tf) then
        neighbour_8.rt = true;
        len_8 = len_8 + 1
    end
    if is_edge_elem(iw, ih - 1, w, h, ftype, tf)then
        neighbour_8.t = true;
        neighbour_4.t = true;
        len_8 = len_8 + 1
        len_4 = len_4 + 1
    end
    if is_edge_elem(iw - 1, ih, w, h, ftype, tf)then
        neighbour_8.l = true;
        neighbour_4.l = true;
        len_8 = len_8 + 1
        len_4 = len_4 + 1
    end
    if is_edge_elem(iw + 1, ih, w, h, ftype, tf)then
        neighbour_8.r = true;
        neighbour_4.r = true;
        len_8 = len_8 + 1
        len_4 = len_4 + 1
    end
    if is_edge_elem(iw - 1, ih + 1, w, h, ftype, tf) then
        neighbour_8.lb = true;
        len_8 = len_8 + 1
    end
    if is_edge_elem(iw + 1, ih + 1, w, h, ftype, tf) then
        neighbour_8.rb = true;
        len_8 = len_8 + 1
    end
    if is_edge_elem(iw, ih + 1, w, h, ftype, tf) then
        neighbour_8.b = true;
        neighbour_4.b = true;
        len_8 = len_8 + 1
        len_4 = len_4 + 1
    end
    return neighbour_8, neighbour_4, len_8, len_4
end

local cterrain_fields = {}

function cterrain_fields.new(st)
    return setmetatable(st, {__index=cterrain_fields})
end



function cterrain_fields:init()
    local tf = self.terrain_fields
    local width, height = self.width, self.height

    for ih = 1, height do
        for iw = 1, width do
            local idx = (ih - 1) * width + iw
            local f = tf[idx]
            local ftype = f.type
            if ftype ~= "n" then
                local neighbour_8, neighbour_4, len_8, len_4 = check_neighbour_elems(iw, ih, width, height, tf, ftype)
                if len_4 == 4 then
                    f.alpha_type = 3
                elseif len_4 == 3 then
                    f.alpha_type = 4
                    if neighbour_4.t == nil then
                        f.alpha_direction = 180
                    elseif neighbour_4.r == nil then
                        f.alpha_direction = 90
                    elseif neighbour_4.b == nil then
                        f.alpha_direction = 0
                    elseif neighbour_4.l == nil then
                        f.alpha_direction = 270                                           
                    end
                elseif len_4 == 2 then
                    if neighbour_4.r == nil and neighbour_4.b == nil then
                        if neighbour_8.rb == nil then
                            f.alpha_type = 2
                            f.alpha_direction = 270
                        else
                            f.alpha_type = 1
                            f.alpha_direction = 180
                        end
                    elseif neighbour_4.r == nil and neighbour_4.t == nil then
                        if neighbour_8.rt == nil then
                            f.alpha_type = 2
                            f.alpha_direction = 0
                        else
                            f.alpha_type = 1
                            f.alpha_direction = 270
                        end
                    elseif neighbour_4.l == nil and neighbour_4.t == nil then
                        if neighbour_8.lt == nil then
                            f.alpha_type = 2
                            f.alpha_direction = 90
                        else
                            f.alpha_type = 1
                            f.alpha_direction = 0
                        end
                    elseif neighbour_4.l == nil and neighbour_4.b == nil then
                        if neighbour_8.lb == nil then
                            f.alpha_type = 2
                            f.alpha_direction = 180
                        else
                            f.alpha_type = 1
                            f.alpha_direction = 90
                        end
                    elseif neighbour_4.l == nil and neighbour_4.r == nil then
                        f.alpha_type = 5
                        f.alpha_direction = 0
                    elseif neighbour_4.t == nil and neighbour_4.b == nil then
                        f.alpha_type = 5
                        f.alpha_direction = 90
                    end
                elseif len_4 == 1 then
                    if neighbour_4.t ~= nil then
                        if neighbour_8.lb == nil and neighbour_8.rb == nil then
                            f.alpha_type = 6
                        elseif neighbour_8.lb ~= nil and neighbour_8.rb ~= nil then
                            f.alpha_type = 7
                        else
                            f.alpha_type = 10
                        end
                        f.alpha_direction = 180                      
                    elseif neighbour_4.r ~= nil then
                        if neighbour_8.lt == nil and neighbour_8.lb == nil then
                            f.alpha_type = 6
                        elseif neighbour_8.lt ~= nil and neighbour_8.lb ~= nil then
                            f.alpha_type = 7
                        else
                            f.alpha_type = 10
                        end
                        f.alpha_direction = 90
                    elseif neighbour_4.b ~= nil then
                        if neighbour_8.lt == nil and neighbour_8.rt == nil then
                            f.alpha_type = 6
                        elseif neighbour_8.lt ~= nil and neighbour_8.rt ~= nil then
                            f.alpha_type = 7
                        else
                            f.alpha_type = 10
                        end
                        f.alpha_direction = 0
                    elseif neighbour_4.l ~= nil then
                        if neighbour_8.rt == nil and neighbour_8.rb == nil then
                            f.alpha_type = 6
                        elseif neighbour_8.rt ~= nil and neighbour_8.rb ~= nil then
                            f.alpha_type = 7
                        else
                            f.alpha_type = 10
                        end
                        f.alpha_direction = 270                                              
                    end
                elseif len_4 == 0 then
                    if neighbour_8.lt ~= nil and neighbour_8.rt ~= nil and neighbour_8.lb ~= nil and neighbour_8.rb ~= nil then
                        f.alpha_type = 8
                    elseif len_8 == 1 and neighbour_8.lt ~= nil then
                        f.alpha_type = 10
                        f.alpha_direction = 270
                    elseif len_8 == 1 and neighbour_8.rt ~= nil then
                        f.alpha_type = 10
                        f.alpha_direction = 180
                    elseif len_8 == 1 and neighbour_8.rb ~= nil then
                        f.alpha_type = 10
                        f.alpha_direction = 90
                    elseif len_8 == 1 and neighbour_8.lb ~= nil then
                        f.alpha_type = 10
                        f.alpha_direction = 0                                                                      
                    elseif neighbour_8.lt == nil and neighbour_8.lb == nil and (neighbour_8.rt ~=nil or neighbour_8.rb ~= nil) then
                        f.alpha_type = 7
                        f.alpha_direction = 0
                    elseif neighbour_8.lt == nil and neighbour_8.rt == nil and (neighbour_8.lb ~=nil or neighbour_8.rb ~= nil) then
                        f.alpha_type = 7
                        f.alpha_direction = 180 
                    elseif neighbour_8.rt == nil and neighbour_8.rb == nil and (neighbour_8.lt ~=nil or neighbour_8.lb ~= nil) then
                        f.alpha_type = 7
                        f.alpha_direction = 90                                             
                    elseif neighbour_8.lb == nil and neighbour_8.rb == nil and (neighbour_8.lt ~=nil or neighbour_8.rt ~= nil) then
                        f.alpha_type = 7
                        f.alpha_direction = 270 
                    else 
                        f.alpha_type = 9 
                    end
                else
                    f.alpha_type = 9
                end                                                       
            end
        end
    end
end

function cterrain_fields:init1()
    local tf = self.terrain_fields
    local width, height = self.width, self.height

    for ih = 1, height do
        for iw = 1, width do
            local idx = (ih - 1) * width + iw
            local f = tf[idx]
            local ftype = f.type
            if ftype ~= "n" then
                local neighbour_8, neighbour_4, len_8, len_4 = check_neighbour_elems(iw, ih, width, height, tf, ftype)
                if len_4 == 4 then
                    f.alpha_type = 3
                elseif len_4 == 3 then
                    f.alpha_type = 4
                    if neighbour_4.t == nil then
                        f.alpha_direction = 180
                    elseif neighbour_4.r == nil then
                        f.alpha_direction = 90
                    elseif neighbour_4.b == nil then
                        f.alpha_direction = 0
                    elseif neighbour_4.l == nil then
                        f.alpha_direction = 270                                           
                    end
                elseif len_4 == 2 then
                    if neighbour_4.r == nil and neighbour_4.b == nil then
                        if neighbour_8.rb == nil then
                            f.alpha_type = 2
                            f.alpha_direction = 270
                        else
                            f.alpha_type = 1
                            f.alpha_direction = 180
                        end
                    elseif neighbour_4.r == nil and neighbour_4.t == nil then
                        if neighbour_8.rt == nil then
                            f.alpha_type = 2
                            f.alpha_direction = 0
                        else
                            f.alpha_type = 1
                            f.alpha_direction = 270
                        end
                    elseif neighbour_4.l == nil and neighbour_4.t == nil then
                        if neighbour_8.lt == nil then
                            f.alpha_type = 2
                            f.alpha_direction = 90
                        else
                            f.alpha_type = 1
                            f.alpha_direction = 0
                        end
                    elseif neighbour_4.l == nil and neighbour_4.b == nil then
                        if neighbour_8.lb == nil then
                            f.alpha_type = 2
                            f.alpha_direction = 180
                        else
                            f.alpha_type = 1
                            f.alpha_direction = 90
                        end
                    elseif neighbour_4.l == nil and neighbour_4.r == nil then
                        f.alpha_type = 5
                        f.alpha_direction = 0
                    elseif neighbour_4.t == nil and neighbour_4.b == nil then
                        f.alpha_type = 5
                        f.alpha_direction = 90
                    end
                elseif len_4 == 1 then
                    if neighbour_4.t ~= nil then
                        if neighbour_8.lb == nil and neighbour_8.rb == nil then
                            f.alpha_type = 6
                        elseif neighbour_8.lb ~= nil and neighbour_8.rb ~= nil then
                            f.alpha_type = 7
                        else
                            f.alpha_type = 10
                        end
                        f.alpha_direction = 180                      
                    elseif neighbour_4.r ~= nil then
                        if neighbour_8.lt == nil and neighbour_8.lb == nil then
                            f.alpha_type = 6
                        elseif neighbour_8.lt ~= nil and neighbour_8.lb ~= nil then
                            f.alpha_type = 7
                        else
                            f.alpha_type = 10
                        end
                        f.alpha_direction = 90
                    elseif neighbour_4.b ~= nil then
                        if neighbour_8.lt == nil and neighbour_8.rt == nil then
                            f.alpha_type = 6
                        elseif neighbour_8.lt ~= nil and neighbour_8.rt ~= nil then
                            f.alpha_type = 7
                        else
                            f.alpha_type = 10
                        end
                        f.alpha_direction = 0
                    elseif neighbour_4.l ~= nil then
                        if neighbour_8.rt == nil and neighbour_8.rb == nil then
                            f.alpha_type = 6
                        elseif neighbour_8.rt ~= nil and neighbour_8.rb ~= nil then
                            f.alpha_type = 7
                        else
                            f.alpha_type = 10
                        end
                        f.alpha_direction = 270                                              
                    end
                elseif len_4 == 0 then
                    if neighbour_8.lt ~= nil and neighbour_8.rt ~= nil and neighbour_8.lb ~= nil and neighbour_8.rb ~= nil then
                        f.alpha_type = 8
                    elseif len_8 == 1 and neighbour_8.lt ~= nil then
                        f.alpha_type = 10
                        f.alpha_direction = 270
                    elseif len_8 == 1 and neighbour_8.rt ~= nil then
                        f.alpha_type = 10
                        f.alpha_direction = 180
                    elseif len_8 == 1 and neighbour_8.rb ~= nil then
                        f.alpha_type = 10
                        f.alpha_direction = 90
                    elseif len_8 == 1 and neighbour_8.lb ~= nil then
                        f.alpha_type = 10
                        f.alpha_direction = 0                                                                      
                    elseif neighbour_8.lt == nil and neighbour_8.lb == nil and (neighbour_8.rt ~=nil or neighbour_8.rb ~= nil) then
                        f.alpha_type = 7
                        f.alpha_direction = 0
                    elseif neighbour_8.lt == nil and neighbour_8.rt == nil and (neighbour_8.lb ~=nil or neighbour_8.rb ~= nil) then
                        f.alpha_type = 7
                        f.alpha_direction = 180 
                    elseif neighbour_8.rt == nil and neighbour_8.rb == nil and (neighbour_8.lt ~=nil or neighbour_8.lb ~= nil) then
                        f.alpha_type = 7
                        f.alpha_direction = 90                                             
                    elseif neighbour_8.lb == nil and neighbour_8.rb == nil and (neighbour_8.lt ~=nil or neighbour_8.rt ~= nil) then
                        f.alpha_type = 7
                        f.alpha_direction = 270 
                    else 
                        f.alpha_type = 9 
                    end
                else
                    f.alpha_type = 9
                end                                                       
            end
        end
    end
end

local packfmt<const> = "ffffffff"
local function add_quad(vb, origin, extent, uv0, uv1, uv2, dir, ftype)
    local ox, oy, oz = table.unpack(origin)
    local nx, ny, nz = ox + extent[1], oy + extent[2], oz + extent[3]
    local u00, v00, u01, v01 = table.unpack(uv0)
    local u10, v10, u11, v11 = table.unpack(uv1)
    local u20, v20, u21, v21 = table.unpack(uv2)

     if dir == 90 then
        local v = {
            packfmt:pack(ox, oy, oz, ftype, u01, v01, u10, v11, u21, v21),
            packfmt:pack(ox, oy, nz, ftype, u00, v01, u10, v10, u20, v21),
            packfmt:pack(nx, ny, nz, ftype, u00, v00, u11, v10, u20, v20),
            packfmt:pack(nx, ny, oz, ftype, u01, v00, u11, v11, u21, v20)
        }
        vb[#vb+1] = table.concat(v, "")
    elseif dir == 180 then
        local v = {
            packfmt:pack(ox, oy, oz, ftype, u01, v00, u10, v11, u21, v20),
            packfmt:pack(ox, oy, nz, ftype, u01, v01, u10, v10, u21, v21),
            packfmt:pack(nx, ny, nz, ftype, u00, v01, u11, v10, u20, v21),
            packfmt:pack(nx, ny, oz, ftype, u00, v00, u11, v11, u20, v20)
        }
        vb[#vb+1] = table.concat(v, "")
    elseif dir == 270 then
        local v = {
            packfmt:pack(ox, oy, oz, ftype, u00, v00, u10, v11, u20, v20),
            packfmt:pack(ox, oy, nz, ftype, u01, v00, u10, v10, u21, v20),
            packfmt:pack(nx, ny, nz, ftype, u01, v01, u11, v10, u21, v21),
            packfmt:pack(nx, ny, oz, ftype, u00, v01, u11, v11, u20, v21)
        }        
        vb[#vb+1] = table.concat(v, "")
    else 
        local v = {
            packfmt:pack(ox, oy, oz, ftype, u00, v01, u10, v11, u20, v21),
            packfmt:pack(ox, oy, nz, ftype, u00, v00, u10, v10, u20, v20),
            packfmt:pack(nx, ny, nz, ftype, u01, v00, u11, v10, u21, v20),
            packfmt:pack(nx, ny, oz, ftype, u01, v01, u11, v11, u21, v21)
        } 
        vb[#vb+1] = table.concat(v, "")             
    end 


end



local function add_quad1(vb, origin, extent, uv0, xx, yy, offset, noise1)
    local ox, oy, oz = table.unpack(origin)
    local nx, ny, nz = ox + extent[1], oy + extent[2], oz + extent[3]
    local u00, v00, u01, v01 = table.unpack(uv0)

    local i1 = calc_tf_idx(xx    ,     yy , 8)
    local i2 = calc_tf_idx(xx + 1,     yy , 8)
    local i3 = calc_tf_idx(xx + 1, yy + 1 , 8)
    local i4 = calc_tf_idx(xx    , yy + 1 , 8)
    local ns1, ns2, ns3, ns4 = noise1[i1], noise1[i2], noise1[i3], noise1[i4]
    local stone_idx = offset % 2 + 1
    local sand_idx = offset % 3 + 1
    if (xx * yy) % 2 == 0 then
        stone_idx = 3 - stone_idx
    else
        sand_idx = 4 - sand_idx
    end 

    local v = {
        packfmt:pack(ox, oy, oz, stone_idx, u01, v01, ns1, sand_idx),
        packfmt:pack(ox, oy, nz, stone_idx, u00, v01, ns2, sand_idx),
        packfmt:pack(nx, ny, nz, stone_idx, u00, v00, ns3, sand_idx),
        packfmt:pack(nx, ny, oz, stone_idx, u01, v00, ns4, sand_idx)
        
    }
    vb[#vb+1] = table.concat(v, "")
    
end

-- 2x4 tiles for shape texture
local SHAPE_NUM_UV_ROW<const>, SHAPE_NUM_UV_COL<const> = 2, 5
local SHAPE_UV_TILES = {}
do
    local row_step<const>, col_step<const> = 1.0 / SHAPE_NUM_UV_ROW, 1.0 / SHAPE_NUM_UV_COL
    for ir = 1, SHAPE_NUM_UV_ROW do
        local v0, v1 = (ir-1)*row_step, ir*row_step
        for ic=1, SHAPE_NUM_UV_COL do
            local u0, u1 = (ic-1)*col_step, ic*col_step
            SHAPE_UV_TILES[#SHAPE_UV_TILES+1] = {u0, v0, u1, v1}
        end
    end
end

-- 1x9 tiles for alpha texture
local ALPHA_NUM_UV_ROW<const>, ALPHA_NUM_UV_COL<const> = 2, 5
local ALPHA_UV_TILES = {}
do
    local row_step<const>, col_step<const> = 1.0 / ALPHA_NUM_UV_ROW, 1.0 / ALPHA_NUM_UV_COL
    for ir = 1, ALPHA_NUM_UV_ROW do
        local v0, v1 = (ir-1)*row_step, ir*row_step
        for ic=1, ALPHA_NUM_UV_COL do
            local u0, u1 = (ic-1)*col_step, ic*col_step
            ALPHA_UV_TILES[#ALPHA_UV_TILES+1] = {u0, v0, u1, v1}
        end
    end
end

local function find_opacity_uv(type)
    return ALPHA_UV_TILES[type]
end

--[[
    field:
        type: [none, grass, dust]
        height: 0.0
        edges: {left, right, top, bottom}
]]
function cterrain_fields:get_field(sidx, iw, ih)
    local ish = (sidx - 1) // self.section_width
    local isw = (sidx - 1) % self.section_width

    local offset = (ish * self.section_size+ih - 1) * self.width +
                    isw * self.section_size + iw
    local y = isw * self.section_size + iw
    local x = (ish * self.section_size+ih)
    return x, y, offset, self.terrain_fields[offset]
end

function cterrain_fields:get_offset(sidx)
    local ish = (sidx-1) // self.section_width
    local isw = (sidx-1) % self.section_width
    return isw * self.section_size, ish * self.section_size
end

local function build_mesh(sectionsize, sectionidx, unit, cterrainfileds, noise1)
    local vb = {}
    for ih = 1, sectionsize do
        for iw = 1, sectionsize do
            local xx, yy, offset, field = cterrainfileds:get_field(sectionidx, iw, ih)
            if field.type == "g" or field.type == "d" then
                local x, z = cterrainfileds:get_offset(sectionidx)
                local origin = {(iw - 1 + x) * unit, 0.0, (ih - 1 + z) * unit}
                local extent = {unit, 0, unit}
                local uv0 = {0.0, 0.0, 1.0, 1.0}
                add_quad1(vb, origin, extent, uv0, xx, yy, offset, noise1)
            end
        end
    end

    if #vb > 0 then
        local min_x, min_z = cterrainfileds:get_offset(sectionidx)
        local max_x, max_z = (min_x + sectionsize) * unit, (min_z + sectionsize) * unit
        return to_mesh_buffer(vb, math3d.aabb(math3d.vector(min_x, 0, min_z), math3d.vector(max_x, 0, max_z)))
    end
end

local function read_terrain_field(tf)
    if type(tf) == "string" then
        return datalist.parse(fs.open(fs.path(tf)):read "a")
    end

    return tf
end

local function is_power_of_2(n)
	if n ~= 0 then
		local l = math.log(n, 2)
		return math.ceil(l) == math.floor(l)
	end
end

function p_ts:entity_init()

    for e in ww:select "INIT shape_terrain:in eid:in" do
        local st = e.shape_terrain

        if st.terrain_fields == nil then
            error "need define terrain_field, it should be file or table"
        end
        --st.terrain_fields = read_terrain_field(st.terrain_fields)

        local width, height = st.width, st.height
        if width * height ~= #st.terrain_fields then
            error(("height_fields data is not equal 'width' and 'height':%d, %d"):format(width, height))
        end

        if not (is_power_of_2(width) and is_power_of_2(height)) then
            error(("one of the 'width' or 'heigth' is not power of 2"):format(width, height))
        end

        local ss = st.section_size
        if not is_power_of_2(ss) then
            error(("'section_size':%d, is not power of 2"):format(ss))
        end

        if ss == 0 or ss > width or ss > height then
            error(("invalid 'section_size':%d, larger than 'width' or 'height' or it is 0: %d, %d"):format(ss, width, height))
        end

        st.section_width, st.section_height = width // ss, height // ss
        st.num_section = st.section_width * st.section_height

        local unit = st.unit
        local shapematerial = st.material

        local ctf = cterrain_fields.new(st)
        --ctf:init1()
        local noise1 = noise(9, 9, 1, 1.1, 0, 1)
        for ih = 1, st.section_height do
            for iw = 1, st.section_width do
                local sectionidx = (ih - 1) * st.section_width + iw
                
                local terrain_mesh = build_mesh(ss, sectionidx, unit, ctf, noise1)
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
                            shape_terrain_drawer = true,
                            on_ready = function()
                                world:pub {"shape_terrain", "on_ready", eid, e.eid}
                            end,
                        },
                    }
                end
            end
        end
    end
end