local ecs = ...
local world = ecs.world
local w = world.w

local bgfx      = require "bgfx"
local declmgr   = require "vertexdecl_mgr"
local viewidmgr = require "viewid_mgr"
local ilight    = ecs.import.interface "ant.render|ilight"
local icompute  = ecs.import.interface "ant.render|icompute"

local cfs = ecs.system "cluster_forward_system"

local cluster_grid_x<const>, cluster_grid_y<const>, cluster_grid_z<const> = 16, 9, 24
local cluster_cull_light_size<const> = 8
assert(cluster_cull_light_size * 3 == cluster_grid_z)
local cluster_count<const> = cluster_grid_x * cluster_grid_y * cluster_grid_z
local cluster_size<const> = {cluster_grid_x, cluster_grid_y, cluster_grid_z}

--[[
    struct light_grids {
        uint offset;
        uint count;
    };
]]
local light_grid_buffer_size<const> = cluster_count * 2
--[[
    struct light_info{
        vec3	pos;
        float   range;
        vec3	dir;
        float   enable;
        vec4	color;
        float	type;
        float	intensity;
        float	inner_cutoff;
        float	outter_cutoff;
    };
]]
local light_struct_size_in_vec4<const>     = 4  --sizeof(light_info), vec4 * 4

--[[
    struct light_aabb{
        vec4 minv;
        vec4 maxv;
    };
]]
local cluster_aabb_size_in_vec4<const> = 2  --sizeof(light_aabb)
local cluster_aabb_buffer_size<const> = cluster_count * cluster_aabb_size_in_vec4

-- cluster [forward] render system
--1. build cluster aabb
--2. find visble cluster. [opt]
--3. cull lights
--4. shading

local cluster_buffers = {
    AABB = {
        build_stage = 0,
        cull_stage = 0,
        build_access = "w",
        cull_access = "r",
        name = "CLUSTER_BUFFER_AABB_STAGE",
        layout = declmgr.get "t40",
    },
    -- TODO: not use
    -- index buffer of 32bit, and only 1 element
    global_index_count = {
        cull_stage = 1,
        cull_access = "rw",
        name = "CLUSTER_BUFFER_GLOBAL_INDEX_COUNT_STAGE",
    },
    -- index buffer of 32bit
    light_grids = {
        cull_stage = 2,
        render_stage = 10,
        cull_access = "w",
        render_access = "r",
        name = "CLUSTER_BUFFER_LIGHT_GRID_STAGE",
    },
    -- index buffer of 32bit
    light_index_lists = {
        cull_stage = 3,
        size = 0,
        cull_access = "w",
        render_access = "r",
        render_stage = 11,
        name = "CLUSTER_BUFFER_LIGHT_INDEX_LIST_STAGE",
    },
    --[[
        struct light_info{
            vec4 pos; vec4 dir; vec4 color; 
            vec4 param;
        };
    ]]
    light_info = {
        build_stage = 4,
        cull_stage = 4,
        render_stage = 12,
        build_access = "r",
        cull_access = "r",
        render_access = "r",
        name = "CLUSTER_BUFFER_LIGHT_INFO_STAGE",
        layout = declmgr.get "t40",
    }
}

cluster_buffers.light_grids.handle         = bgfx.create_dynamic_index_buffer(light_grid_buffer_size, "drw")
cluster_buffers.global_index_count.handle  = bgfx.create_dynamic_index_buffer(1, "drw")
cluster_buffers.AABB.handle                = bgfx.create_dynamic_vertex_buffer(cluster_aabb_buffer_size, cluster_buffers.AABB.layout.handle, "rw")
cluster_buffers.light_index_lists.handle   = bgfx.create_dynamic_index_buffer(1, "drw")

local function check_light_index_list()
    local numlights = ilight.count_visible_light()
    local lil_size = numlights * cluster_count
    local lil = cluster_buffers.light_index_lists
    local oldhandle = lil.handle
    if lil_size > lil.size then
        if lil.handle then
            bgfx.destroy(lil.handle)
        end
        lil.handle = bgfx.create_dynamic_index_buffer(lil_size, "drw")
        lil.size = lil_size
    end
    if lil.handle ~= oldhandle then
        assert(lil.handle)
        local ce = w:singleton("cluster_cull_light", "dispatch:in")
        ce.dispatch.properties.b_light_index_lists.handle = lil.handle

        local cr = w:object("cluster_render", 1)
        cr.properties.b_light_index_lists.handle = lil.handle
    end
    return true
end

local main_viewid = viewidmgr.get "main_view"

local function build_cluster_aabb_struct(viewid)
    local e = w:singleton("cluster_build_aabb", "dispatch:in")
    icompute.dispatch(viewid, e.dispatch)
end

local cr_camera_mb      = world:sub{"main_queue", "camera_changed"}
local camera_frustum_mb

function cfs:init()
    icompute.create_compute_entity(
        "cluster_build_aabb", 
        "/pkg/ant.resources/materials/cluster_build.material",
        cluster_size)
    icompute.create_compute_entity(
        "cluster_cull_light",
        "/pkg/ant.resources/materials/cluster_light_cull.material",
        {1, 1, cluster_cull_light_size})

    ecs.create_entity {
        policy = {
            "ant.render|cluster_render_entity",
            "ant.general|name",
        },
        data = {
            name = "cluster_render_entity",
            cluster_render = {
                properties = {},
                cluster_size = cluster_size,
            },
        }
    }
end

function cfs:init_world()
    local mq = w:singleton("main_queue", "camera_ref:in")
    camera_frustum_mb = world:sub{"camera_changed", mq.camera_ref}

    cluster_buffers.light_info.handle = ilight.light_buffer()

    --build
    local be = w:singleton("cluster_build_aabb", "dispatch:in")
    local bm = be.dispatch.material
    bm.b_cluster_AABBs    = icompute.create_buffer_property(cluster_buffers.AABB, "build")
    bm.b_light_info       = icompute.create_buffer_property(cluster_buffers.light_info, "build")

    --cull
    local ce = w:singleton("cluster_cull_light", "dispatch:in")
    local cm = ce.dispatch.material

    cm.b_cluster_AABBs       = icompute.create_buffer_property(cluster_buffers.AABB, "cull")
    cm.b_global_index_count  = icompute.create_buffer_property(cluster_buffers.global_index_count, "cull")
    cm.b_light_grids         = icompute.create_buffer_property(cluster_buffers.light_grids, "cull")
    cm.b_light_index_lists   = icompute.create_buffer_property(cluster_buffers.light_index_lists, "cull")
    cm.b_light_info          = icompute.create_buffer_property(cluster_buffers.light_info, "cull")

    --render
    local cr = w:object("cluster_render", 1)
    local rm = cr.material

    rm.b_light_grids          = icompute.create_buffer_property(cluster_buffers.light_grids, "render")
    rm.b_light_index_lists    = icompute.create_buffer_property(cluster_buffers.light_index_lists, "render")
    rm.b_light_info           = icompute.create_buffer_property(cluster_buffers.light_info, "render")
end

local function cull_lights(viewid)
    local e = w:singleton("cluster_cull_light", "dispatch:in")
    icompute.dispatch(viewid, e.dispatch)
end

local rebuild_light_index_list

function cfs:entity_init()
    if not ilight.use_cluster_shading() then
        return
    end

    for _ in w:select "INIT light:in" do
        rebuild_light_index_list = true
    end
end

function cfs:entity_remove()
    if not ilight.use_cluster_shading() then
        return
    end

    for _ in w:select "REMOVED light:in" do
        rebuild_light_index_list = true
    end
end

function cfs:data_changed()
    if not ilight.use_cluster_shading() then
        return
    end

    for msg in cr_camera_mb:each() do
        build_cluster_aabb_struct(main_viewid)
        camera_frustum_mb = world:sub{"camera_changed", msg[3]}
    end

    for _ in camera_frustum_mb:each() do
        build_cluster_aabb_struct(main_viewid)
    end

    if rebuild_light_index_list then
        check_light_index_list()
        rebuild_light_index_list = false
    end
end

function cfs:render_preprocess()
    if not ilight.use_cluster_shading() then
        return
    end

    cull_lights(main_viewid)
end

local ics = ecs.interface "icluster_render"
ics.build_cluster_aabbs     = build_cluster_aabb_struct
ics.cull_lights             = cull_lights
