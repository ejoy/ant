local ecs   = ...
local world = ecs.world
local w     = world.w

local bgfx      = require "bgfx"
local math3d    = require "math3d"
local road_system   = ecs.system "road_system"
local imaterial     = ecs.require "ant.asset|material"
local idrawindirect = ecs.require "ant.render|draw_indirect.draw_indirect"
local irender       = ecs.require "ant.render|render_system.render"
local renderpkg     = import_package "ant.render"
local layoutmgr     = renderpkg.layoutmgr
local layout        = layoutmgr.get "p3|t20"

local iroad         = {}

local rot_table = {
    N = {0,   270, 180, 0},
    E = {270, 0,   90,  0},
    S = {180, 90,  0,   0},
    W = {90,  80,  270, 0},
}
local SHAPE_TYPES<const> = {
    U = {shape = 1, rot_idx = 1},
    I = {shape = 2, rot_idx = 2},
    L = {shape = 3, rot_idx = 3},
    T = {shape = 4, rot_idx = 1},
    X = {shape = 5, rot_idx = 4},
    O = {shape = 6, rot_idx = 4},
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

-- local function build_ib(num_quad)
--     local b = {}
--     for ii=1, num_quad do
--         local offset = (ii-1) * 4
--         b[#b+1] = offset + 0
--         b[#b+1] = offset + 1
--         b[#b+1] = offset + 2

--         b[#b+1] = offset + 2
--         b[#b+1] = offset + 3
--         b[#b+1] = offset + 0
--     end
--     return bgfx.create_index_buffer(bgfx.memory_buffer("w", b))
-- end

local function build_mesh(ww, hh)
    local packfmt<const> = "fffff"
    local ox, oz = 0, 0
    local nx, nz = ww,hh
    local vb = {
        packfmt:pack(ox, 0, oz, 0, 1),
        packfmt:pack(ox, 0, nz, 0, 0),
        packfmt:pack(nx, 0, nz, 1, 0),
        packfmt:pack(nx, 0, oz, 1, 1),
    }
    return to_mesh_buffer(vb, irender.quad_ib())
end

local function get_srt_info_table(update_list)
    local function get_layer_info(instance, layer, info_table)
        local sd_info = SHAPE_TYPES[layer.shape]
        local state, dir, shape = layer.state, rot_table[layer.dir][sd_info.rot_idx], sd_info.shape
        local current_info_table = info_table[shape]
        current_info_table[#current_info_table+1] = {
            {instance.x, 0.1, instance.y, 0},
            {dir, state, 0, 0},
        }
    end

    local road_info_table = {}
    local mark_info_table = {}

    for ii = 1, #update_list do
        local instance = update_list[ii]
        local layers = instance.layers
        local road, indicator = layers.road, layers.indicator
        if road then
            road_info_table[#road_info_table+1] = {
                s = 0.1, 
            }
            --get_layer_info(instance, road, road_info_table)
        end

        if indicator then
            get_layer_info(instance, indicator, mark_info_table)
        end
    end
    return road_info_table, mark_info_table
end

function iroad.create(width, height)
    local mesh = build_mesh()

end

function iroad.update_roadnet_group(gid, update_list, render_layer)
    local function update_layer_entity(info_table, material_table, indirect_table)
        for srt_idx = 1, 6 do
            local srt_info = info_table[srt_idx]
            if indirect_table[srt_idx] then
                local e <close> = world:entity(indirect_table[srt_idx], "road:update draw_indirect_update?out")
                e.road.srt_info = srt_info
                e.draw_indirect_update = true
            else
                local eid = world:create_entity {
                    policy = {
                        "ant.render|simplerender",
                        "ant.render|draw_indirect",
                        "ant.landform|road",
                    },
                    data = {
                        scene = {},
                        simplemesh  = mesh,
                        material    = material_table[srt_idx],
                        visible_state = "main_view|selectable|pickup",
                        road = {srt_info = srt_info},
                        render_layer = render_layer,
                        draw_indirect = {
                            --TODO: fix me
                            instance_buffer = {
                                memory  = ('\0'):rep(48),
                                flag    = "r",
                                layout  = "t45NIf|t46NIf|t47NIf",
                                num     = 0,
                            },
                            indirect_type_NEED_REMOVED = math3d.ref(math3d.vector(3, 0, 0, 0)),
                        },
                        --TODO: fix me
                        on_ready = function(e)
                            imaterial.set_property(e, "u_draw_indirect_type", math3d.vector(0, 0, 0, 0))
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

function road_system:entity_remove()
    for e in w:select "REMOVED road:in" do
        
    end
end

return iroad
