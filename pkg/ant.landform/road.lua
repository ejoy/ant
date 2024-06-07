local ecs   = ...
local world = ecs.world
local w     = world.w

local bgfx      = require "bgfx"
local math3d    = require "math3d"
local assetmgr  = import_package "ant.asset"
local irender       = ecs.require "ant.render|render"
local icompute      = ecs.require "ant.render|compute.compute"
local idi           = ecs.require "ant.render|draw_indirect.draw_indirect"
local renderpkg     = import_package "ant.render"
local layoutmgr     = renderpkg.layoutmgr
local layout        = layoutmgr.get "p3|t20"
local hwi           = import_package "ant.hwi"
local DEFAULT_SIZE<const> = 50
local ROAD_ENTITIES = {}
-- local ROT_TABLES = {
--     N = {0,   270, 180, 0},
--     E = {270, 0,   90,  0},
--     S = {180, 90,  0,   0},
--     W = {90,  180, 270, 0},
-- }

-- the color&alpha/rougness&metalness texture are 1024x128
local DEFAULT_QUAD_TEX_SIZE<const> = 128
local NUM_QUAD_IN_TEX<const> = 8
local DEFAULT_TEX_WIDTH<const>, DEFAULT_TEX_HEIGHT<const> = NUM_QUAD_IN_TEX * DEFAULT_QUAD_TEX_SIZE, DEFAULT_QUAD_TEX_SIZE

local DEFAULT_QUAD_UV_SIZE<const> = {DEFAULT_QUAD_TEX_SIZE/DEFAULT_TEX_WIDTH, 1.0}
local DEFAULT_TEXEL_SIZE<const> = {1.0/DEFAULT_TEX_WIDTH, 1.0/DEFAULT_TEX_HEIGHT}
local UV_THRESHOLD<const>   = {1e-6, 1e-6}

--[[
    v1---v3
    |    |
    v0---v2
]]
local DEFAULT_QUAD_TEXCOORD<const> = {
    {0, DEFAULT_QUAD_UV_SIZE[2]},                       -- quad v0
    {0, 0},                                             -- quad v1
    {DEFAULT_QUAD_UV_SIZE[1], DEFAULT_QUAD_UV_SIZE[2]}, -- quad v2
    {DEFAULT_QUAD_UV_SIZE[1], 0},                       -- quad v3
}

--the color/alpha/rm texture are packed from NUM_SHAPES images into [NUM_SHAPES * DEFAULT_TEXTURE_QUAD_SIZE[1], DEFAULT_TEXTURE_QUAD_SIZE[2]], so we only refine the texcoord on u direction
local function shrink_uv_rect(uv_rect)
    -- we make left u to step in UV_THRESHOLD[1] value, make right u to step in -UV_THRESHOLD[1]
    --left u
    local delta = DEFAULT_TEXEL_SIZE[1]
    uv_rect[1][1] = uv_rect[1][1] + delta
    uv_rect[2][1] = uv_rect[2][1] + delta

    --right u
    uv_rect[3][1] = uv_rect[3][1] - delta
    uv_rect[4][1] = uv_rect[4][1] - delta
    return uv_rect
end

shrink_uv_rect(DEFAULT_QUAD_TEXCOORD)

local QUAD_TEXCOORDS = {
    [0] = DEFAULT_QUAD_TEXCOORD,
}

for i=90, 270, 90 do
    local l = QUAD_TEXCOORDS[i-90]
    QUAD_TEXCOORDS[i] = {
        l[3],
        l[1],
        l[4],
        l[2],
    }
end

local SHAPE_DIRECTIONS<const> = {
    "N", "E", "S", "W",
    N = 1,
    E = 2,
    S = 3,
    W = 4,
}

local SHAPE_TYPES<const> = {
    "U", "I", "L", "T", "O", "X",
    U = {
        index = 1,
        direction = {
            N = QUAD_TEXCOORDS[0],
            E = QUAD_TEXCOORDS[90],
            S = QUAD_TEXCOORDS[180],
            W = QUAD_TEXCOORDS[270],
        }
    },
    I = {
        index = 2,
        direction = {
            N = QUAD_TEXCOORDS[270],
            E = QUAD_TEXCOORDS[0],
            S = QUAD_TEXCOORDS[90],
            W = QUAD_TEXCOORDS[180],
        }
    },
    L = {
        index = 3,
        direction = {
            N = QUAD_TEXCOORDS[180],
            E = QUAD_TEXCOORDS[270],
            S = QUAD_TEXCOORDS[0],
            W = QUAD_TEXCOORDS[90],
        }
    },
    T = {
        index = 4,
        direction = {
            N = QUAD_TEXCOORDS[0],
            E = QUAD_TEXCOORDS[90],
            S = QUAD_TEXCOORDS[180],
            W = QUAD_TEXCOORDS[270],
        },
    },
    O = {
        index = 5,
        direction = {
            N = QUAD_TEXCOORDS[0],
            E = QUAD_TEXCOORDS[0],
            S = QUAD_TEXCOORDS[0],
            W = QUAD_TEXCOORDS[0],
        }
    },
    X = {
        index = 6,
        direction = {
            N = QUAD_TEXCOORDS[0],
            E = QUAD_TEXCOORDS[0],
            S = QUAD_TEXCOORDS[0],
            W = QUAD_TEXCOORDS[0],
        }
    },
}

local function offset_uv(uv, shapetype)
    return {uv[1] + (shapetype-1)*DEFAULT_QUAD_UV_SIZE[1], uv[2]}
end

for _, sn in ipairs(SHAPE_TYPES) do
    local s = assert(SHAPE_TYPES[sn])
    for n, d in pairs(s.direction) do
        -- create new uv
        local nd = {}
        for i=1, #d do
            nd[i] = offset_uv(d[i], s.index)
        end
        s.direction[n] = nd
    end
end

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

local ROAD_MESH
local VBFMT<const> = ("fffff"):rep(4)
-- local DEBUG_VERTEX<const> = true
-- local function pack_vertex(...)
--     if DEBUG_VERTEX then
--         return {...}
--     end
--     return VBFMT:pack(...)
-- end
local function build_vb(ox, oz, ww, hh, texcoords, vb)
    local nx, nz = ox+ww, oz+hh
    vb[#vb+1] = VBFMT:pack(
        ox, 0, oz, texcoords[1][1], texcoords[1][2],
        ox, 0, nz, texcoords[2][1], texcoords[2][2],
        nx, 0, oz, texcoords[3][1], texcoords[3][2],
        nx, 0, nz, texcoords[4][1], texcoords[4][2])
end

local road_sys   = ecs.system "road_system"

local function destroy_handle(h)
    if h then
        bgfx.destroy(h)
    end
end

function road_sys:entity_init()
    for e in w:select "INIT road owned_mesh_buffer:out" do
		e.owned_mesh_buffer = false
    end
end

function road_sys:entity_remove()
    for e in w:select "REMOVED road:in" do
        e.road.handle = destroy_handle(e.road.handle)
    end
end

function road_sys:exit()
    if ROAD_MESH and ROAD_MESH.vb.handle then
        ROAD_MESH.vb.handle = destroy_handle(ROAD_MESH.vb.handle)
    end
    for _, entities in pairs(ROAD_ENTITIES) do
        for _, entity in pairs(entities) do
            w:remove(entity.drawindirect)
            w:remove(entity.compute)
        end
    end
end

local function to_dispath_num(indirectnum)
    return (indirectnum+63) // 64
end

local main_viewid<const> = hwi.viewid_get "main_view"

local function dispath_road_indirect_buffer(e, dieid)
    local die = world:entity(dieid, "draw_indirect:in road:in")
    local di = die.draw_indirect

    local instancenum = di.instance_buffer.num
    if instancenum > 0 then
        local dis = e.dispatch
        local m = dis.material
        dis.size[1] = to_dispath_num(instancenum)

        local ibnum<const> = 6
        m.u_mesh_param = math3d.vector(ibnum, instancenum, 0, 0)
        m.b_mesh_buffer = {
            type = "b",
            access = "r",
            value = die.road.handle,
            stage = 0,
        }
        m.b_indirect_buffer = {
            type = "b",
            access = "w",
            value = di.handle,
            stage = 1,
        }
    
        icompute.dispatch(main_viewid, dis)
    end
end

local INSTANCEBUFFER_FMT<const> = 'ffIf'
local MESHBUFFER_FMT<const> = 'BB'

local function build_instance_buffers(infos)
    local roadbuffer, indicatorbuffer = {}, {}
    local roadmeshbuffer, indicatormeshbuffer = {}, {}
    for _, i in pairs(infos) do
        local p = i.pos

        local function add_buffer(t, ib, mb)
            ib[#ib+1] = INSTANCEBUFFER_FMT:pack(p[1], p[2], t.color, 0)
            mb[#mb+1] = MESHBUFFER_FMT:pack(SHAPE_TYPES[t.shape].index-1, SHAPE_DIRECTIONS[t.dir]-1)
        end

        local r = i.road
        if r then
            add_buffer(r, roadbuffer, roadmeshbuffer)
        end

        local indicator = i.indicator
        if indicator then
            add_buffer(indicator, indicatorbuffer, indicatormeshbuffer)
        end
    end

    return {
        road = {
            instancebuffer = roadbuffer,
            meshbuffer = roadmeshbuffer,
        },
        indicator = {
            instancebuffer = indicatorbuffer,
            meshbuffer = indicatormeshbuffer,
        }
    }
end

local function create_mesh_buffer(b)
    if #b > 0 then
        return bgfx.create_dynamic_index_buffer(irender.align_buffer(table.concat(b, "")), "dr")
    end
end

local function update_di_buffers(dieid, buffer)
    local die = world:entity(dieid, "road:update")
    local r = die.road

    if r.handle then
        bgfx.update(r.handle, 0, irender.align_buffer(table.concat(buffer.meshbuffer)))
    else
        die.road.handle = create_mesh_buffer(buffer.meshbuffer)
    end

    idi.update_instance_buffer(die, table.concat(buffer.instancebuffer, ""), #buffer.instancebuffer)
end

local function create_road_obj(gid, render_layer, buffer, dimaterial, cs_material)
    local instancenum = #buffer.instancebuffer
    local dieid = world:create_entity {
        group = gid,
        policy = {
            "ant.render|simplerender",
            "ant.render|draw_indirect",
            "ant.landform|road",
        },
        data = {
            scene = {},
            mesh_result = assert(ROAD_MESH),
            material    = dimaterial,
            visible     = true,
            visible_masks = "main_view|selectable",
            road = {
                handle = create_mesh_buffer(buffer.meshbuffer),
            },
            render_layer = render_layer,
            draw_indirect = {
                instance_buffer = {
                    memory  = table.concat(buffer.instancebuffer, ""),
                    flag    = "r",
                    layout  = "t45NIf",
                    num     = instancenum,
                    size    = DEFAULT_SIZE
                },
            },
        },
    }

    local computeeid = world:create_entity{
        policy = {
            "ant.render|compute",
        },
        data = {
            material = cs_material,
            dispatch = {
                size = {1, 1, 1},
            },
            on_ready = function (e)
                w:extend(e, "dispatch:update")
                assetmgr.material_mark(e.dispatch.fx.prog)
                dispath_road_indirect_buffer(e, dieid)
            end
        }
    }

    return {
        drawindirect = dieid,
        compute = computeeid,
    }
end

local function create_road_entities(gid, render_layer, road, indicator, road_material, indicator_material, cs_material)
    return {
        road        = create_road_obj(gid, render_layer, road,      road_material, cs_material),
        indicator   = create_road_obj(gid, render_layer, indicator, indicator_material, cs_material),
    }
end


local iroad         = {}
local function build_road_mesh(rw, rh)
    local road_vb = {}
    --we need keep shapes and directions order in SHAPE_TYPES&SHAPE_DIRECTIONS
    for _, s in ipairs(SHAPE_TYPES) do
        local st = SHAPE_TYPES[s]
        for _, dn in ipairs(SHAPE_DIRECTIONS) do
            build_vb(0, 0, rw, rh, st.direction[dn], road_vb)
        end
    end

    assert(#road_vb == #SHAPE_TYPES * #SHAPE_DIRECTIONS)
    -- if DEBUG_VERTEX then
    --     for i=1, #road_vb do
    --         road_vb[i] = VBFMT:pack(table.unpack(road_vb[i]))
    --     end
    -- end
    return to_mesh_buffer(road_vb, irender.quad_ib())
end

function iroad.create(roadwidth, roadheight)
    ROAD_MESH = build_road_mesh(roadwidth, roadheight)
end

function iroad.update_roadnet(groups, render_layer, road_material, indicator_material, cs_material)
    for gid, infos in pairs(groups) do
        local entities = ROAD_ENTITIES[gid]
        local buffers = build_instance_buffers(infos)
        --print(("group:%d, road instance num:%d, indicator instance num:%d"):format(gid, #buffers.road, #buffers.indicator))
        if nil == entities then
            entities = create_road_entities(gid, render_layer, buffers.road, buffers.indicator, road_material, indicator_material, cs_material)
            ROAD_ENTITIES[gid] = entities
        else
            local function update_buffer_and_dispatch(buffer, eids)
                update_di_buffers(eids.drawindirect, buffer)
                dispath_road_indirect_buffer(world:entity(eids.compute, "dispatch:update"), eids.drawindirect)
            end

            update_buffer_and_dispatch(buffers.road,        entities.road)
            update_buffer_and_dispatch(buffers.indicator,   entities.indicator)
        end
    end
end

function iroad.clear(groups, layer)
    for gid in pairs(groups) do
        local entities = ROAD_ENTITIES[gid]
        if entities then
            local o = entities[layer]
            if o then
                w:remove(o.drawindirect)
                w:remove(o.compute)
            end
        end
        ROAD_ENTITIES[gid] = nil
    end
end

return iroad
