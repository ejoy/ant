local ecs       = ...
local world     = ecs.world
local w         = world.w

local bgfx      = require "bgfx"
local math3d    = require "math3d"

local renderpkg = import_package "ant.render"
local layoutmgr = renderpkg.layoutmgr

local layout    = layoutmgr.get "p3|t20"

local imaterial = ecs.require "ant.asset|material"
local iplane_terrain  = ecs.require "ant.landform|plane_terrain"

local tp_sys  = ecs.system 'translucent_plane_system'

local itp = {}
local translucent_plane_material
local tp_table = {}
local NUM_QUAD_VERTICES<const> = 4
local tp_update
local remove_update
local cur_tp_idx = 0
local remove_list = {}
local intersect_table = {}
local width, height, unit, offset
--build ib
local function build_ib(max_plane)
    do
        local planeib = {}
        planeib = {
            0, 1, 2,
            2, 3, 0,
        }
        local fmt<const> = ('I'):rep(#planeib)
        local offset<const> = NUM_QUAD_VERTICES
        local s = #fmt * 4


        local m = bgfx.memory_buffer(s * max_plane)
        for i=1, max_plane do
            local mo = s * (i - 1) + 1
            m[mo] = fmt:pack(table.unpack(planeib))
            for ii = 1, #planeib do
                planeib[ii]  = planeib[ii] + offset
            end
        end
        return bgfx.create_index_buffer(m, "d")
    end
end

local function to_mesh_buffer(vb, ib_handle, aabb)
    local vbbin = table.concat(vb, "")
    local numv = #vbbin // layout.stride
    local numi = (numv // NUM_QUAD_VERTICES) * 6 --6 for one quad 2 triangles and 1 triangle for 3 indices
    if numv < 1 then return end
    return {
        bounding = {aabb = aabb },
        vb = {
            start = 0,
            num = numv,
            handle = bgfx.create_vertex_buffer(bgfx.memory_buffer(vbbin), layout.handle),
            owned = true
        },
        ib = {
            start = 0,
            num = numi,
            handle = ib_handle,
            owned = true
        }
    }
end

local function build_mesh(grids, grids_num, aabb)
    local packfmt<const> = "fffff"
    local vb = {}
    for grid, _ in pairs(grids) do
        if grid ~= "rect" then
            local cx, cz = grid >> 8, grid & 0xff
            local ox, oz = cx * unit, cz * unit
            local nx, nz = ox + unit, oz + unit
            local v = {
                packfmt:pack(ox, 0, oz, 0, 1),
                packfmt:pack(ox, 0, nz, 0, 0),
                packfmt:pack(nx, 0, nz, 1, 0),
                packfmt:pack(nx, 0, oz, 1, 1),        
            }
            vb[#vb+1] = table.concat(v, "")
        end
    end
    local ib_handle = build_ib(grids_num)
    return to_mesh_buffer(vb, ib_handle, aabb)
end

local function get_aabb(grids)
    width, height, unit, offset = iplane_terrain.get_wh()
    local minx, minz = width + 1, height + 1
    local maxx, maxz = -1, -1
    for grid,  _ in pairs(grids) do
        if grid ~= "rect" then
            local cx, cz = grid >> 8, grid & 0xff
            if cx > maxx then
                maxx = cx
            end
            if cx < minx then
                minx = cx
            end
            if cz > maxz then
                maxz = cz
            end
            if cz < minz then
                minz = cz
            end 
        end
    end
    local aabb_min = {minx * unit, 0, minz * unit}
    local aabb_max = {minx * unit + unit, 0, minz * unit + unit}
    return {aabb_min, aabb_max}
end

function tp_sys:init_world()
    translucent_plane_material = "/pkg/ant.landform/assets/materials/translucent_plane.material"
end


local function create_translucent_plane_entity(grids_num, grids, color, alpha, render_layer)
    width, height, unit, offset = iplane_terrain.get_wh()
    if grids_num == 0 then
        return
    end
    local aabb = get_aabb(grids)
    local plane_mesh = build_mesh(grids, grids_num, aabb)
    local eid
    if plane_mesh then
        if alpha then
            eid = world:create_entity {
                policy = {
                    "ant.scene|scene_object",
                    "ant.render|simplerender",
                },
                data = {
                    scene = {
                        t = math3d.vector(-offset * unit, 0, -offset * unit)
                    },
                    simplemesh  = plane_mesh,
                    material    = translucent_plane_material,
                    on_ready = function (e)
                        imaterial.set_property(e, "u_basecolor_factor", math3d.vector(color[1], color[2], color[3], alpha.min))
                    end,
                    breath = {
                        min = alpha.min,
                        max = alpha.max,
                        cur = alpha.min,
                        freq = alpha.freq,
                        trend = 0,
                        color = {color[1], color[2], color[3]}
                    },
                    visible_state = "main_view",
                    --render_layer = "translucent",
                    render_layer = render_layer
                },
            }
        else
            eid = world:create_entity {
                policy = {
                    "ant.scene|scene_object",
                    "ant.render|simplerender",
                },
                data = {
                    scene = {
                        t = math3d.vector(-offset * unit, 0, -offset * unit)
                    },
                    simplemesh  = plane_mesh,
                    material    = translucent_plane_material,
                    on_ready = function (e)
                        imaterial.set_property(e, "u_basecolor_factor", math3d.vector(color))
                    end,
                    visible_state = "main_view",
                    --render_layer = "translucent",
                    render_layer = render_layer
                },
            }

        end
    end
    return eid
end 

local function get_intersect_tp(table, rect, remove_idx)
    local function is_intersect(r1, r2)
        width, height, unit, offset = iplane_terrain.get_wh()
        local xmin1, zmin1, xmax1, zmax1 = r1.x + offset, r1.z + offset - r1.h + 1, r1.x + offset + r1.w - 1, r1.z + offset
        local xmin2, zmin2, xmax2, zmax2 = r2.x + offset, r2.z + offset - r2.h + 1, r2.x + offset + r2.w - 1, r2.z + offset
        if xmin1 > xmax2 or xmax1 < xmin2 or zmin1 > zmax2 or zmax1 < zmin2 then return
        else return true end
    end
    for tp_idx, tp in pairs(tp_table) do
        if remove_idx and remove_idx == tp_idx then
        elseif is_intersect(rect, tp.rect) then
            table[tp_idx] = true
        end
    end
end

local function update_intersect_tp()
    width, height, unit, offset = iplane_terrain.get_wh()
    local has_mark = {}
    local t_table = {}
    local t_sum = 0
    --idx从高到低排序，grid画过的打上标记
    for k, _ in pairs(intersect_table) do
         t_sum = t_sum + 1
         t_table[k] = true
    end
    while t_sum > 0 do
        local max_tp_idx = -1        for k, _ in pairs(t_table) do
            if k > max_tp_idx then
                max_tp_idx = k
            end
        end
        local tp = tp_table[max_tp_idx]
        if tp then
            local rect = tp.rect
            local x, z, ww, hh = rect.x + offset, rect.z + offset, rect.w, rect.h
            local grids = {}
            local grids_num = 0
            for ih = 0, hh - 1 do
                for iw = 0, ww - 1 do
                    local xx, zz = x + iw, z - ih
                    local compress_coord = (xx << 8) + zz
                    if not has_mark[compress_coord] then
                        grids[compress_coord] = true
                        has_mark[compress_coord] = true
                        grids_num = grids_num + 1
                    end
                end
            end
            tp.grids, tp.grids_num = grids, grids_num 
        end
        t_table[max_tp_idx] = nil
        t_sum = t_sum - 1
    end
end

local function update_build_tp()
    for tp_idx, _ in pairs(intersect_table) do
        if not tp_update then tp_update = {} end
        tp_update[tp_idx] = true
    end
end

local function remove_old_tp()
    for tp_idx, _ in pairs(intersect_table) do
        local tp = tp_table[tp_idx]
        if tp and tp.eid and not remove_list[tp.eid] then
            remove_list[tp.eid] = true
            tp.eid = nil
        end
    end

end

function itp.create_translucent_plane(rect, color, render_layer, alpha)
    local new_tp = {rect = rect, color = color, render_layer = render_layer, alpha = alpha}
    cur_tp_idx = cur_tp_idx + 1
    get_intersect_tp(intersect_table, rect)
    remove_old_tp()
    tp_table[cur_tp_idx] = new_tp
    intersect_table[cur_tp_idx] = true
    update_build_tp()
    return cur_tp_idx
end

function itp.remove_translucent_plane(remove_idx)
    remove_update = true
    local remove_tp = tp_table[remove_idx]
    if remove_tp then
        if remove_tp.eid and (not remove_list[remove_tp.eid]) then
            remove_list[remove_tp.eid] = true
        end
        get_intersect_tp(intersect_table, remove_tp.rect, remove_idx)
        remove_old_tp()
        tp_table[remove_idx] = nil
        update_build_tp()
    end
end

local function update_intersect_table()
    local neighbour_table = {}
    for tp_idx, _ in pairs(intersect_table) do
        if tp_table[tp_idx] and tp_table[tp_idx].rect then
            get_intersect_tp(neighbour_table, tp_table[tp_idx].rect)
        end
        neighbour_table[tp_idx] = true
    end
    intersect_table = neighbour_table
end

function tp_sys:data_changed()
    for e in w:select "breath:update" do
        local min, max, cur, freq, trend, color = e.breath.min, e.breath.max, e.breath.cur, e.breath.freq, e.breath.trend, e.breath.color
        local increment = (1 / 60) * freq
        if trend == 0 then
            cur = cur + increment
            if cur > max then
                cur, trend = max, 1
            end
        else
            cur = cur - increment
            if cur < min then
                cur, trend = min, 0
            end
        end
        e.breath.cur, e.breath.trend = cur, trend
        imaterial.set_property(e, "u_basecolor_factor", math3d.vector(color[1], color[2], color[3], cur))
    end

    if tp_update or remove_update then
        for eid, _ in pairs(remove_list) do
            w:remove(eid)
        end
        remove_list = {}
        if tp_update then
            update_intersect_table()
            update_intersect_tp()
            for tp_idx, _ in pairs(tp_update) do
                if tp_table and tp_table[tp_idx] then
                    local tp = tp_table[tp_idx]
                    local eid = create_translucent_plane_entity(tp.grids_num, tp.grids, tp.color, tp.alpha, tp.render_layer)
                    if eid then
                        tp.eid = eid
                    end 
                end
            end 
        end
        tp_update = nil
        remove_update = nil
        intersect_table = {}
    end
end

return itp
