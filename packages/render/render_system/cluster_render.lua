local ecs = ...
local world = ecs.world

local math3d    = require "math3d"
local bgfx      = require "bgfx"
local declmgr   = require "vertexdecl_mgr"
local assetmgr  = import_package "ant.asset"
local irq       = world:interface "ant.render|irenderqueue"
local iom       = world:interface "ant.objcontroller|obj_motion"
local ilight    = world:interface "ant.render|light"
local icamera   = world:interface "ant.camera|camera"
local isp       = world:interface "ant.render|system_properties"

local cfs = ecs.system "cluster_forward_system"

local cluster_grid_x<const>, cluster_grid_y<const>, cluster_grid_z<const> = 16, 9, 24
local cluster_cull_light_size<const> = 6
assert(cluster_cull_light_size * 4 == cluster_grid_z)
local cluster_count<const> = cluster_grid_x * cluster_grid_y * cluster_grid_z

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

local cluster_aabb_fx, cluster_light_cull_fx

-- cluster [forward] render system
--1. build cluster aabb
--2. find visble cluster. [opt]
--3. cull lights
--4. shading

local cluster_buffers = {
    AABB = {
        stage = 0,
        build_access = "w",
        cull_access = "r",
        name = "CLUSTER_BUFFER_AABB_STAGE",
        layout = declmgr.get "t40",
    },
    -- index buffer of 32bit, and only 1 element
    global_index_count = {
        stage = 1,
        cull_access = "rw",
        name = "CLUSTER_BUFFER_GLOBAL_INDEX_COUNT_STAGE",
    },
    -- index buffer of 32bit
    light_grids = {
        stage = 2,
        render_stage = 10,
        cull_access = "w",
        render_access = "r",
        name = "CLUSTER_BUFFER_LIGHT_GRID_STAGE",
    },
    -- index buffer of 32bit
    light_index_list = {
        stage = 3,
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
        stage = 4,
        render_stage = 12,
        build_access = "r",
        cull_access = "r",
        render_access = "r",
        name = "CLUSTER_BUFFER_LIGHT_INFO_STAGE",
        layout = declmgr.get "t40",
    }
}


local function create_cluster_buffers()
    local lights = ilight.create_light_buffers()
    local numlights = #lights

    if numlights > 0 then
        cluster_buffers.AABB.handle                = bgfx.create_dynamic_vertex_buffer(cluster_aabb_buffer_size, cluster_buffers.AABB.layout.handle, "rwa") 
        cluster_buffers.light_grids.handle         = bgfx.create_dynamic_index_buffer(light_grid_buffer_size, "drwa")
        cluster_buffers.global_index_count.handle  = bgfx.create_dynamic_index_buffer(1, "drwa")


        cluster_buffers.light_index_list.handle    = bgfx.create_dynamic_index_buffer(numlights * cluster_count, "drwa")
        cluster_buffers.light_info.handle          = bgfx.create_vertex_buffer(bgfx.memory_buffer(table.concat(lights, "")), cluster_buffers.light_info.layout.handle, "r")
        return true
    end
end

local function set_buffers(which_stage, which_access)
    for _, b in pairs(cluster_buffers) do
        local access = b[which_access]
        if access then
            bgfx.set_buffer(b[which_stage], b.handle, access)
        end
    end
end

local function build_cluster_aabb_struct()
    if cluster_aabb_fx == nil then
        return
    end
    local mq_eid = world:singleton_entity_id "main_queue"
    set_buffers("stage", "build_access")
    local icr = world:interface "ant.render|icluster_render"
    
    local properties = isp.properties()
    icr.extract_cluster_properties(properties)

    for _, u in ipairs(cluster_aabb_fx.uniforms) do
        bgfx.set_uniform(u.handle, assert(properties[u.name]).value)
    end

    bgfx.dispatch(irq.viewid(mq_eid), cluster_aabb_fx.prog, cluster_grid_x, cluster_grid_y, cluster_grid_z)
end

local cr_camera_mb
local camera_frustum_mb
local light_mb = world:sub{"component_register", "light_type"}
local light_change_mb

function cfs:init()
    ilight.use_cluster_shading(true)
end

local function check_init()
    if cluster_light_cull_fx == nil and cluster_aabb_fx == nil then
        if create_cluster_buffers() then
            cluster_aabb_fx = assetmgr.load_fx{
                cs = "/pkg/ant.resources/shaders/compute/cs_cluster_aabb.sc",
                setting = {CLUSTER_BUILD=1},
            }
            cluster_light_cull_fx = assetmgr.load_fx{
                cs = "/pkg/ant.resources/shaders/compute/cs_lightcull.sc",
                setting = {CLUSTER_PREPROCESS=1}
            }
            build_cluster_aabb_struct()
        end
    end
end

function cfs:post_init()
    local mq_eid = world:singleton_entity_id "main_queue"
    cr_camera_mb = world:sub{"component_changed", "camera_eid", mq_eid}
    camera_frustum_mb = world:sub{"component_changed", "frustum", world[mq_eid].camera_eid}
end

function cfs:data_changed()
    if not ilight.use_cluster_shading() then
        return
    end
    for _ in light_mb:unpack() do
        check_init()
    end

    local mq = world:singleton_entity "main_queue"
    for _ in cr_camera_mb:unpack() do
        build_cluster_aabb_struct()
        camera_frustum_mb = world:sub{"component_changed", "frustum", mq.camera_eid}
    end

    for _ in camera_frustum_mb:unpack() do
        build_cluster_aabb_struct()
    end
end

local function cull_lights()
    if cluster_light_cull_fx == nil then
        return
    end
    local mq_eid = world:singleton_entity_id "main_queue"

    --TODO: need abstract compute dispatch pipeline, which like render pipeline
    local properties = isp.properties()
    for _, u in ipairs(cluster_light_cull_fx.uniforms) do
        bgfx.set_uniform(u.handle, assert(properties[u.name]).value)
    end
    set_buffers("stage", "cull_access")

    --workgroup size: 16, 9, 4
    bgfx.dispatch(irq.viewid(mq_eid), cluster_light_cull_fx.prog, 1, 1, cluster_cull_light_size)
end

function cfs:render_preprocess()
    if not ilight.use_cluster_shading() then
        return
    end
    cull_lights()
end

local icr = ecs.interface "icluster_render"

function icr.set_buffers()
    if cluster_light_cull_fx then
        set_buffers("render_stage", "render_access")
    end
end

function icr.cluster_sizes()
    return {cluster_grid_x, cluster_grid_y, cluster_grid_z}
end

function icr.extract_cluster_properties(properties)
    local mq_eid = world:singleton_entity_id "main_queue"
	local mq = world[mq_eid]
	local mc_eid = mq.camera_eid

	local vr = irq.view_rect(mq_eid)

	local sizes = icr.cluster_sizes()
	sizes[4] = vr.w / sizes[1]
	assert(properties["u_cluster_size"]).v				= sizes
	local f = icamera.get_frustum(mc_eid)
	local near, far = f.n, f.f
	assert(properties["u_cluster_shading_param"]).v	= {vr.w, vr.h, near, far}
	local num_depth_slices = sizes[3]
	local log_farnear = math.log(far/near, 2)
	local log_near = math.log(near)

	assert(properties["u_cluster_shading_param2"]).v	= {num_depth_slices / log_farnear, -num_depth_slices * log_near / log_farnear, 0, 0}
end