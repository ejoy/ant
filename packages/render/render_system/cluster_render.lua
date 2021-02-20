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

local lighttypes = {
	directional = 0,
	point = 1,
	spot = 2,
}

local function create_light_buffers()
	local lights = {}
	for _, leid in world:each "light_type" do
		local le = world[leid]
		
		local p	= math3d.tovalue(iom.get_position(leid))
		local d	= math3d.tovalue(iom.get_direction(leid))
		local c = ilight.color(leid)
		local t	= le.light_type
        local enable<const> = 1
        --TODO: use bgfx.memory{('f'):rep(16), }
		lights[#lights+1] = ('f'):rep(16):pack(
			p[1], p[2], p[3], ilight.range(leid),
			d[1], d[2], d[3], enable,
			c[1], c[2], c[3], c[4],
			lighttypes[t], ilight.intensity(leid),
			ilight.inner_cutoff(leid),	ilight.outter_cutoff(leid))
	end
    return lights
end

local function create_cluster_buffers()
    cluster_buffers.AABB.handle                = bgfx.create_dynamic_vertex_buffer(cluster_aabb_buffer_size, cluster_buffers.AABB.layout.handle, "rwa")
    cluster_buffers.light_grids.handle         = bgfx.create_dynamic_index_buffer(light_grid_buffer_size, "drwa")
    cluster_buffers.global_index_count.handle  = bgfx.create_dynamic_index_buffer(1, "drwa")

    local lights = create_light_buffers()
    local numlights = #lights
    cluster_buffers.light_index_list.handle    = bgfx.create_dynamic_index_buffer(numlights, "drwa")
    cluster_buffers.light_info.handle          = bgfx.create_vertex_buffer(bgfx.memory_buffer(table.concat(lights, "")), cluster_buffers.light_info.layout.handle, "r")
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

function cfs:init()
    
end

function cfs:post_init()
    local mq_eid = world:singleton_entity_id "main_queue"
    cr_camera_mb = world:sub{"component_changed", "camera_eid", mq_eid}
    camera_frustum_mb = world:sub{"component_changed", "frustum", world[mq_eid].camera_eid}

    create_cluster_buffers()

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

function cfs:data_changed()
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
    cull_lights()
end

local icr = ecs.interface "icluster_render"

function icr.set_buffers()
    set_buffers("render_stage", "render_access")
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
	sizes[4] = sizes[1] / vr.w
	assert(properties["u_cluster_size"]).v				= sizes
	local f = icamera.get_frustum(mc_eid)
	local near, far = f.n, f.f
	assert(properties["u_cluster_shading_param"]).v	= {vr.w, vr.h, near, far}
	local num_depth_slices = sizes[3]
	local log_farnear = math.log(far/near, 2)
	local log_near = math.log(near)

	assert(properties["u_cluster_shading_param2"]).v	= {num_depth_slices / log_farnear, -num_depth_slices * log_near / log_farnear, 0, 0}
end