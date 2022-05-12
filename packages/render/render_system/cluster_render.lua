local ecs = ...
local world = ecs.world
local w = world.w

local bgfx      = require "bgfx"
local math3d    = require "math3d"
local declmgr   = require "vertexdecl_mgr"
local viewidmgr = require "viewid_mgr"
local ilight    = ecs.import.interface "ant.render|ilight"
local icompute  = ecs.import.interface "ant.render|icompute"
local imaterial = ecs.import.interface "ant.asset|imaterial"

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
        local mo = ce.dispatch.material:get_material()
        mo:set_attrib("b_light_index_lists", lil.handle)

        local sa = imaterial.system_attribs()
        sa:update("b_light_index_lists",    lil.handle)
    end
    return true
end

local main_viewid = viewidmgr.get "main_view"

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
end

local function update_render_info()
    -- we assume all the buffer will not change
    local sa = imaterial.system_attribs()
    sa:update("b_light_grids",          assert(cluster_buffers.light_grids.handle))
    sa:update("b_light_index_lists",    assert(cluster_buffers.light_index_lists.handle))
    sa:update("b_light_info",           assert(cluster_buffers.light_info.handle))

    sa:update("u_cluster_size",         math3d.vector(cluster_size))
end

local function update_shading_param(ce)
    local f = ce.camera.frustum
    local near, far = f.n, f.f
    local num_depth_slices = cluster_size[3]
	local log_farnear = math.log(far/near, 2)
	local log_near = math.log(near, 2)

    local mq = w:singleton("main_queue", "render_target:in")
    local vr = mq.render_target.view_rect

    local sa = imaterial.system_attribs()
	sa:update("u_cluster_shading_param", math3d.vector(
		num_depth_slices / log_farnear, -num_depth_slices * log_near / log_farnear,
		vr.w / cluster_size[1], vr.h/cluster_size[2]))
end

local function build_cluster_aabb_struct(viewid, ceid)
    update_shading_param(world:entity(ceid))

    local e = w:singleton("cluster_build_aabb", "dispatch:in")
    icompute.dispatch(viewid, e.dispatch)
end

function cfs:init_world()
    local mq = w:singleton("main_queue", "camera_ref:in")
    local ceid = mq.camera_ref
    camera_frustum_mb = world:sub{"camera_changed", ceid}

    cluster_buffers.light_info.handle = ilight.light_buffer()

    update_render_info()

    --build
    local be = w:singleton("cluster_build_aabb", "dispatch:in")
    local bmo= be.dispatch.material:get_material()
    bmo:set_attrib("b_cluster_AABBs",       icompute.create_buffer_property(cluster_buffers.AABB, "build"))
    bmo:set_attrib("b_light_info",          icompute.create_buffer_property(cluster_buffers.light_info, "build"))

    build_cluster_aabb_struct(main_viewid, ceid)

    --cull
    local ce = w:singleton("cluster_cull_light", "dispatch:in")
    local cmo = ce.dispatch.material:get_material()
    cmo:set_attrib("b_cluster_AABBs",       icompute.create_buffer_property(cluster_buffers.AABB, "cull"))
    cmo:set_attrib("b_global_index_count",  icompute.create_buffer_property(cluster_buffers.global_index_count, "cull"))
    cmo:set_attrib("b_light_grids",         icompute.create_buffer_property(cluster_buffers.light_grids, "cull"))
    cmo:set_attrib("b_light_index_lists",   icompute.create_buffer_property(cluster_buffers.light_index_lists, "cull"))
    cmo:set_attrib("b_light_info",          icompute.create_buffer_property(cluster_buffers.light_info, "cull"))
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
        local ceid = msg[3]
        camera_frustum_mb = world:sub{"camera_changed", msg[3]}
        build_cluster_aabb_struct(main_viewid, ceid)
    end

    for _, ceid in camera_frustum_mb:unpack() do
        build_cluster_aabb_struct(main_viewid, ceid)
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
