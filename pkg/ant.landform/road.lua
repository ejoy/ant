local ecs   = ...
local world = ecs.world
local w     = world.w

local bgfx      = require "bgfx"
local math3d    = require "math3d"
local road_system   = ecs.system "road_system"
local imaterial     = ecs.require "ant.asset|material"
local idrawindirect = ecs.require "ant.render|draw_indirect_system"
local renderpkg     = import_package "ant.render"
local layoutmgr     = renderpkg.layoutmgr
local layout        = layoutmgr.get "p3|t20"
local hwi                   = import_package "ant.hwi"
local iroad         = {}
local width, height = 20, 20

local road_material_table = {
    "/pkg/ant.landform/assets/materials/road_u.material",
    "/pkg/ant.landform/assets/materials/road_i.material",
    "/pkg/ant.landform/assets/materials/road_l.material",
    "/pkg/ant.landform/assets/materials/road_t.material",
    "/pkg/ant.landform/assets/materials/road_x.material",
    "/pkg/ant.landform/assets/materials/road_o.material",
}

local mark_material_table = {
    "/pkg/ant.landform/assets/materials/mark_u.material",
    "/pkg/ant.landform/assets/materials/mark_i.material",
    "/pkg/ant.landform/assets/materials/mark_l.material",
    "/pkg/ant.landform/assets/materials/mark_t.material",
    "/pkg/ant.landform/assets/materials/mark_x.material",
    "/pkg/ant.landform/assets/materials/mark_o.material",
}

local rot_table = {['N'] = {0, 270, 180, 0}, ['E'] = {270, 0, 90, 0}, ['S'] = {180, 90, 0, 0}, ['W'] = {90, 80, 270, 0}}
local shape_dir_table = {
    ['U'] = {shape = 0, rot_idx = 1}, ['I'] = {shape = 1, rot_idx = 2}, ['L'] = {shape = 2, rot_idx = 3}, 
    ['T'] = {shape = 3, rot_idx = 1}, ['X'] = {shape = 4, rot_idx = 4}, ['O'] = {shape = 5, rot_idx = 4}
}

local road_indirect_table = {}
local mark_indirect_table = {}

local NUM_QUAD_VERTICES<const> = 4

local function to_mesh_buffer(vb, ib_handle)
    local vbbin = table.concat(vb, "")
    local numv = #vbbin // layout.stride
    local numi = (numv // NUM_QUAD_VERTICES) * 6 --6 for one quad 2 triangles and 1 triangle for 3 indices

    return {
        bounding = nil,
        vb = {
            start = 0,
            num = numv,
            handle = bgfx.create_vertex_buffer(bgfx.memory_buffer(vbbin), layout.handle),
        },
        ib = {
            start = 0,
            num = numi,
            handle = ib_handle,
        }
    }
end

local function build_ib(num_quad)
    local b = {}
    for ii=1, num_quad do
        local offset = (ii-1) * 4
        b[#b+1] = offset + 0
        b[#b+1] = offset + 1
        b[#b+1] = offset + 2

        b[#b+1] = offset + 2
        b[#b+1] = offset + 3
        b[#b+1] = offset + 0
    end
    return bgfx.create_index_buffer(bgfx.memory_buffer("w", b))
end

local function build_mesh()
    local packfmt<const> = "fffff"
    local ox, oz = 0, 0
    local nx, nz = width, height
    local vb = {
        packfmt:pack(ox, 0, oz, 0, 1),
        packfmt:pack(ox, 0, nz, 0, 0),
        packfmt:pack(nx, 0, nz, 1, 0),
        packfmt:pack(nx, 0, oz, 1, 1),        
    }
    local ib_handle = build_ib(1)
    return to_mesh_buffer(vb, ib_handle)
end

local mesh = build_mesh()

local function get_srt_info_table(update_list)
    local function get_layer_info(instance, layer, info_table)
        local sd_info = shape_dir_table[layer.shape]
        local type, dir, shape = layer.type, rot_table[layer.dir][sd_info.rot_idx], sd_info.shape
        local current_info_table = info_table[shape+1]
        current_info_table[#current_info_table+1] = {
            math3d.vector(instance.x, 0.1, instance.y, 0),
            math3d.vector(dir, type, 0, 0),
            math3d.vector(0, 0, 0, 0)
        }
    end
    local mt = {__index=function(t, k) local tt = {}; t[k] = tt; return tt end}
    local road_info_table = setmetatable({}, mt)
    local mark_info_table = setmetatable({}, mt)
    for ii = 1, #update_list do
        local road_instance = update_list[ii]
        local road_layer, mark_layer = road_instance.layers.road, road_instance.layers.mark
        if road_layer then get_layer_info(road_instance, road_layer, road_info_table) end
        if mark_layer then get_layer_info(road_instance, mark_layer, mark_info_table) end
    end
    return road_info_table, mark_info_table
end

function iroad.set_args(ww, hh)
    width, height = ww, hh
end

function iroad.update_roadnet_group(gid, update_list, render_layer)
    local function update_layer_entity(info_table, material_table, indirect_table)
        for srt_idx = 1, 6 do
            local srt_info = info_table[srt_idx]
            if indirect_table[srt_idx] then
                local e <close> = world:entity(indirect_table[srt_idx], "road:update draw_indirect_update:update")
                e.road.srt_info = srt_info
                e.draw_indirect_update = true
            else
                local eid = world:create_entity {
                    policy = {
                        "ant.scene|scene_object",
                        "ant.render|simplerender",
                        "ant.landform|road",
                        "ant.render|indirect"
                    },
                    data = {
                        scene = {},
                        simplemesh  = mesh,
                        material    = material_table[srt_idx],
                        visible_state = "main_view|selectable|pickup",
                        road = {srt_info = srt_info, road_type = srt_idx},
                        render_layer = render_layer,
                        draw_indirect_ready = false,
                        draw_indirect_update = false,
                        indirect = "ROAD",
                        on_ready = function(e)
                            local draw_indirect_type = idrawindirect.get_draw_indirect_type("ROAD")
                            imaterial.set_property(e, "u_draw_indirect_type", math3d.vector(draw_indirect_type))
                        end
                    },
                }
                indirect_table[srt_idx] = eid
            end
        end
    end
    if not render_layer then render_layer = "background" end
    local road_info_table, mark_info_table = get_srt_info_table(update_list)
    update_layer_entity(road_info_table, road_material_table, road_indirect_table)
    update_layer_entity(mark_info_table, mark_material_table, mark_indirect_table)
end

function road_system:entity_init()
    for e in w:select "INIT road:update render_object?update indirect?update eid:in" do
        local road = e.road
        local draw_num = #road.srt_info
        local max_num = 500
        local draw_indirect_eid = world:create_entity {
            policy = {
                "ant.render|draw_indirect"
            },
            data = {
                draw_indirect = {
                    target_eid = e.eid,
                    itb_flag = "r",
                    draw_num = draw_num,
                    max_num = max_num,
                    srt_table = e.road.srt_info,
                    indirect_params_table = {math3d.vector(0, 0, 6, 0)},
                    aabb_table = {math3d.ref(math3d.aabb(math3d.vector(0, 0, 0), math3d.vector(20, 0, 20)))},
                    indirect_type = "road"
                },
                on_ready = function()
                    road.ready = true
                end 
            }
        }
        road.draw_indirect_eid = draw_indirect_eid
        e.render_object.draw_num = 0
        e.render_object.idb_handle = 0xffffffff
        e.render_object.itb_handle = 0xffffffff 
    end
    
end

function road_system:entity_remove()
    for e in w:select "REMOVED road:in" do
        w:remove(e.road.draw_indirect_eid)
    end
end

function road_system:data_changed()
    for e in w:select "road:update render_object:update scene:in draw_indirect_ready:update" do
        if e.draw_indirect_ready ~= true then
            goto continue
        end
        local road = e.road
        local srt_info = road.srt_info
        local draw_num = 0
        if srt_info then draw_num = #srt_info end
        local de <close> = world:entity(road.draw_indirect_eid, "draw_indirect:in")
        local idb_handle, itb_handle = de.draw_indirect.idb_handle, de.draw_indirect.itb_handle
        e.render_object.idb_handle = idb_handle
        e.render_object.itb_handle = itb_handle
        if draw_num > 0 then
            e.render_object.draw_num = draw_num
        else
            e.render_object.draw_num = 0
        end

        e.draw_indirect_ready = false
        ::continue::
    end
    for e in w:select "road:update render_object:update draw_indirect_update:update" do
        if e.draw_indirect_update ~= true then
            goto continue
        end
        local die <close> = world:entity(e.road.draw_indirect_eid, "draw_indirect:update")
        idrawindirect.update_draw_indirect(e, die, e.road.srt_info)
        e.draw_indirect_update = false
        ::continue::
    end
end

return iroad
