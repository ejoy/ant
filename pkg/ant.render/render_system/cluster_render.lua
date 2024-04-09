local ecs = ...
local world = ecs.world
local w = world.w

local setting   = import_package "ant.settings"

local cfs = ecs.system "cluster_forward_system"

local ENABLE_CLUSTER_SHADERING<const> = setting:get "graphic/lighting/cluster_shading"
if not ENABLE_CLUSTER_SHADERING then
    return
end

local bgfx      = require "bgfx"
local math3d    = require "math3d"
local layoutmgr = require "vertexlayout_mgr"
local hwi       = import_package "ant.hwi"

local assetmgr  = import_package "ant.asset"

local ilight    = ecs.require "ant.render|light.light"
local icompute  = ecs.require "ant.render|compute.compute"
local imaterial = ecs.require "ant.render|material"
local irq       = ecs.require "ant.render|renderqueue"

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
        build_stage     = 0,
        build_access    = "w",

        cull_stage      = 0,
        cull_access     = "r",
        name            = "CLUSTER_BUFFER_AABB_STAGE",
        layout          = layoutmgr.get "t40",
    },
    -- TODO: not use
    -- index buffer of 32bit, and only 1 element
    global_index_count = {
        cull_stage      = 1,
        cull_access     = "rw",
        name            = "CLUSTER_BUFFER_GLOBAL_INDEX_COUNT_STAGE",
    },
    -- index buffer of 32bit
    light_grids = {
        cull_stage      = 2,
        cull_access     = "w",

        render_stage    = 10,
        render_access   = "r",
        name            = "CLUSTER_BUFFER_LIGHT_GRID_STAGE",
    },
    -- index buffer of 32bit
    light_index_lists = {
        cull_stage      = 3,
        cull_access     = "w",

        render_stage    = 11,
        render_access   = "r",
        size            = 0,
        name            = "CLUSTER_BUFFER_LIGHT_INDEX_LIST_STAGE",
    },
    light_info = {
        cull_stage      = 4,
        cull_access     = "r",

        render_stage    = 12,
        render_access   = "r",
        name            = "CLUSTER_BUFFER_LIGHT_INFO_STAGE",
        layout          = layoutmgr.get "t40",
    }
}

cluster_buffers.light_grids.handle         = bgfx.create_dynamic_index_buffer(light_grid_buffer_size, "drw")
cluster_buffers.global_index_count.handle  = bgfx.create_dynamic_index_buffer(1, "drw")
cluster_buffers.AABB.handle                = bgfx.create_dynamic_vertex_buffer(cluster_aabb_buffer_size, cluster_buffers.AABB.layout.handle, "rw")
cluster_buffers.light_index_lists.handle   = bgfx.create_dynamic_index_buffer(1, "drw")

local function rebuild_light_index_list()
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
        local ce = w:first "cluster_cull_light dispatch:in"
        ce.dispatch.material.b_light_index_lists_write = lil.handle

        imaterial.system_attrib_update("b_light_index_lists", lil.handle)
    end
    return true
end

local main_viewid<const> = hwi.viewid_get "main_view"

local cr_camera_mb      = world:sub{"main_queue", "camera_changed"}

function cfs:init()
    local function mark_prog(e)
        w:extend(e, "dispatch:in")
        assetmgr.material_mark(e.dispatch.fx.prog)
    end
    icompute.create_compute_entity(
        "cluster_build_aabb", 
        "/pkg/ant.resources/materials/cluster_build.material",
        cluster_size, mark_prog)
    icompute.create_compute_entity(
        "cluster_cull_light",
        "/pkg/ant.resources/materials/cluster_light_cull.material",
        {1, 1, cluster_cull_light_size}, mark_prog)
end

local function update_scene_render_param()
    -- we assume all the buffer will not change
    imaterial.system_attrib_update("b_light_grids",          assert(cluster_buffers.light_grids.handle))
    imaterial.system_attrib_update("b_light_index_lists",    assert(cluster_buffers.light_index_lists.handle))
    imaterial.system_attrib_update("b_light_info",           assert(cluster_buffers.light_info.handle))

    imaterial.system_attrib_update("u_cluster_size",         math3d.vector(cluster_size))
end

local function update_build_param(ce, material)
    material["u_normal_inv_proj"] = ce.camera.projmat
    local f = ce.camera.frustum
    local nn, ff = f.n, f.f
    local inv_nn, inv_ff = 1.0/nn, 1.0/ff
    material["u_camera_frustum"] = math3d.vector(nn, ff, inv_nn, inv_ff)
end

local function create_buffer_property(bufferdesc, which_stage)
    local stage = which_stage .. "_stage"
    local access = which_stage .. "_access"
    return {
        type    = "b",
        value  = bufferdesc.handle,
        stage   = bufferdesc[stage],
        access  = bufferdesc[access],
    }
end

function cfs:init_world()
    cluster_buffers.light_info.handle = ilight.light_buffer()
    --render
    update_scene_render_param()

    --build
    local be = w:first "cluster_build_aabb dispatch:in"
    local bmi = be.dispatch.material
    bmi.b_cluster_AABBs= create_buffer_property(cluster_buffers.AABB,       "build")

    --cull
    local ce = w:first "cluster_cull_light dispatch:in"
    local cmi = ce.dispatch.material
    cmi.b_cluster_AABBs             = create_buffer_property(cluster_buffers.AABB,                 "cull")
    cmi.b_global_index_count        = create_buffer_property(cluster_buffers.global_index_count,   "cull")
    cmi.b_light_grids_write         = create_buffer_property(cluster_buffers.light_grids,          "cull")
    cmi.b_light_index_lists_write   = create_buffer_property(cluster_buffers.light_index_lists,    "cull")
    cmi.b_light_info_for_cull       = create_buffer_property(cluster_buffers.light_info,           "cull")
end

local function cull_lights(viewid)
    if irq.main_camera_changed() then
        local e = w:first "cluster_cull_light dispatch:in"
        icompute.dispatch(viewid, e.dispatch)
    end
end

local need_rebuild_light_index_list

function cfs:entity_init()
    for _ in w:select "INIT light:in" do
        need_rebuild_light_index_list = true
    end
end

function cfs:entity_remove()
    for _ in w:select "REMOVED light:in" do
        need_rebuild_light_index_list = true
    end
end

local function check_rebuild_cluster_aabb()
    local C
    for _ in cr_camera_mb:each() do
        C = irq.main_camera_entity()
    end

    if not C then
        C = irq.main_camera_changed()
    end
    if C then
        w:extend(C, "camera:in")
        local f = C.camera.frustum
        local near, far = f.n, f.f
        local num_depth_slices = cluster_size[3]
        local log_farnear   = math.log(far/near, 2)
        local log_near      = math.log(near, 2)
    
        local mq = w:first "main_queue render_target:in"
        local vr = mq.render_target.view_rect
    
        imaterial.system_attrib_update("u_cluster_shading_param", math3d.vector(
            num_depth_slices / log_farnear, -num_depth_slices * log_near / log_farnear,
            vr.w / cluster_size[1], vr.h/cluster_size[2]))

        local be = w:first "cluster_build_aabb dispatch:in"
        --no invz, no infinite far
        be.dispatch.material["u_normal_inv_proj"] = math3d.inverse(math3d.projmat(C.camera.frustum))
        icompute.dispatch(main_viewid, be.dispatch)
    end
end

function cfs:camera_usage()
    if need_rebuild_light_index_list then
        rebuild_light_index_list()
        need_rebuild_light_index_list = false
    end
end

function cfs:render_preprocess()
    check_rebuild_cluster_aabb()
    cull_lights(main_viewid)
end
