local ecs = ...
local world = ecs.world
local w = world.w

local bgfx      = require "bgfx"
local declmgr   = require "vertexdecl_mgr"
local ilight    = world:interface "ant.render|light"
local icompute  = world:interface "ant.render|icompute"

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
local cs_entities = {}

local function check_light_index_list()
    local numlights = world:count "light_type"
    if numlights > 0 then
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
            local ce = world[cs_entities.culleid]
            ce._rendercache.properties.b_light_index_lists.handle = lil.handle

            local re = world:singleton_entity "cluster_render"
            re.cluster_render.properties.b_light_index_lists.handle = lil.handle
        end
        return true
    end
end
local function main_viewid()
    for v in w:select "main_queue render_target:in" do
        return v.render_target.viewid
    end
end

local function build_cluster_aabb_struct()
    icompute.dispatch(main_viewid(), world[cs_entities.buildeid]._rendercache)
end

local cr_camera_mb
local camera_frustum_mb
local light_mb = world:sub{"component_register", "light_type"}

function cfs:post_init()
    cluster_buffers.light_info.handle = ilight.light_buffer()

    --build
    local buildeid = icompute.create_compute_entity("build_cluster_aabb", "/pkg/ant.resources/materials/cluster_build.material", cluster_size)
    local be = world[buildeid]
    local buildproperties = be._rendercache.properties
    buildproperties.b_cluster_AABBs    = icompute.create_buffer_property(cluster_buffers.AABB, "build")
    buildproperties.b_light_info       = icompute.create_buffer_property(cluster_buffers.light_info, "build")
    cs_entities.buildeid = buildeid

    --cull
    local culleid = icompute.create_compute_entity("build_cluster_aabb", "/pkg/ant.resources/materials/cluster_light_cull.material", {1, 1, cluster_cull_light_size})
    local ce = world[culleid]
    local cullproperties = ce._rendercache.properties
    for _, b in ipairs{
        {"b_cluster_AABBs",     cluster_buffers.AABB},
        {"b_global_index_count",cluster_buffers.global_index_count},
        {"b_light_grids",       cluster_buffers.light_grids},
        {"b_light_index_lists", cluster_buffers.light_index_lists},
        {"b_light_info",        cluster_buffers.light_info},
    } do
        local name, desc = b[1], b[2]
        cullproperties[name] = icompute.create_buffer_property(desc, "cull")
    end

    cs_entities.culleid = culleid

    --render
    local rendereid = world:create_entity {
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

    local re = world[rendereid]
    local renderproperties = re.cluster_render.properties
    for _, b in ipairs{
        {"b_light_grids", cluster_buffers.light_grids},
        {"b_light_index_lists", cluster_buffers.light_index_lists},
        {"b_light_info", cluster_buffers.light_info},
    } do
        local name, desc = b[1], b[2]
        renderproperties[name] = icompute.create_buffer_property(desc, "render")
    end
end

local function cull_lights()
    icompute.dispatch(main_viewid(), world[cs_entities.culleid]._rendercache)
end

function cfs:render_preprocess()
    if not ilight.use_cluster_shading() then
        return
    end

    for _ in light_mb:each() do
        check_light_index_list()
    end

    build_cluster_aabb_struct()
    cull_lights()
end
