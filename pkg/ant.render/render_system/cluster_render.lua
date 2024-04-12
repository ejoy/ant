local ecs = ...
local world = ecs.world
local w = world.w

local setting   = import_package "ant.settings"

local cfs = ecs.system "cluster_forward_system"

local CLUSTER_SHADING<const> = setting:get "graphic/lighting/cluster_shading"
local ENABLE_CLUSTER_SHADERING<const> = CLUSTER_SHADING.enable
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

--defalut: 16 * 9 * 24
--cull defalut group size: 16 * 9 * 8, dispatch: (x=1, y=1, z=3)
local CLUSTER_SIZE<const>               = CLUSTER_SHADING.size
local CLUSTER_COUNT<const>              = CLUSTER_SIZE[1] * CLUSTER_SIZE[2] * CLUSTER_SIZE[3]
local CLUSTER_MAX_LIGHT_COUNT<const>    = CLUSTER_SHADING.max_light

--[[
    struct light_grids {
        uint offset;
        uint count;
    };
]]
local LIGHT_GRID_BUFFER_SIZE<const> = CLUSTER_COUNT * 2
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
local LIGHT_INFO_SIZE_IN_VEC4<const>     = 4  --sizeof(light_info), vec4 * 4

--[[
    struct light_aabb{
        vec4 minv;
        vec4 maxv;
    };
]]
local CLUSTER_AABB_SIZE_IN_VEC4<const> = 2  --sizeof(light_aabb)
local CLUSTER_AABB_BUFFER_SIZE<const> = CLUSTER_COUNT * CLUSTER_AABB_SIZE_IN_VEC4

-- cluster [forward] render system
--1. build cluster aabb
--2. find visble cluster. [opt]
--3. cull lights
--4. shading

local cluster_buffers = {
    AABB = {
        name            = "CLUSTER_BUFFER_AABB_STAGE",
        layout          = layoutmgr.get "t40",
    },
    -- TODO: not use
    -- index buffer of 32bit, and only 1 element
    global_index_count = {
        name            = "CLUSTER_BUFFER_GLOBAL_INDEX_COUNT_STAGE",
    },
    -- index buffer of 32bit
    light_grids = {
        name            = "CLUSTER_BUFFER_LIGHT_GRID_STAGE",
    },
    -- index buffer of 32bit
    light_index_lists = {
        size            = 0,
        name            = "CLUSTER_BUFFER_LIGHT_INDEX_LIST_STAGE",
    },
    light_info = {
        name            = "CLUSTER_BUFFER_LIGHT_INFO_STAGE",
        layout          = layoutmgr.get "t40",
    }
}

cluster_buffers.light_grids.handle         = bgfx.create_dynamic_index_buffer(LIGHT_GRID_BUFFER_SIZE, "drw")
--cluster_buffers.global_index_count.handle  = bgfx.create_dynamic_index_buffer(1, "drw")
cluster_buffers.AABB.handle                = bgfx.create_dynamic_vertex_buffer(CLUSTER_AABB_BUFFER_SIZE, cluster_buffers.AABB.layout.handle, "rw")
cluster_buffers.light_index_lists.handle   = bgfx.create_dynamic_index_buffer(CLUSTER_MAX_LIGHT_COUNT * CLUSTER_COUNT, "drw")

local CLUSTER_BUILDAABB_EID, CLUSTER_LIGHTCULL_EID

local main_viewid<const> = hwi.viewid_get "main_view"

local cr_camera_mb      = world:sub{"main_queue", "camera_changed"}

local function create_compute_entity(material)
    return world:create_entity{
        policy = {"ant.render|compute"},
        data = {
            material = material,
            dispatch = {
                size = {1, 1, 1},
            },
            on_ready = function (e)
                w:extend(e, "dispatch:in material:in")
                assetmgr.material_mark(e.dispatch.fx.prog)

                local m = assetmgr.resource(e.material)
                local ts = assert(m.fx.setting.threadsize, "must define threadsize for compute shader")
                local s = e.dispatch.size

                for i=1, 3 do
                    s[i] = CLUSTER_SIZE[i] // ts[i]
                    assert(s[i] > 0)
                end
            end
        }
    }
end

function cfs:init()
    CLUSTER_BUILDAABB_EID = create_compute_entity "/pkg/ant.resources/materials/cluster_build.material"
    CLUSTER_LIGHTCULL_EID = create_compute_entity "/pkg/ant.resources/materials/cluster_light_cull.material"
end

local function update_scene_render_param()
    -- we assume all the buffer will not change
    imaterial.system_attrib_update("b_light_grids",          assert(cluster_buffers.light_grids.handle))
    imaterial.system_attrib_update("b_light_index_lists",    assert(cluster_buffers.light_index_lists.handle))
    imaterial.system_attrib_update("b_light_info",           assert(cluster_buffers.light_info.handle))

    imaterial.system_attrib_update("u_cluster_size",         math3d.vector(CLUSTER_SIZE))
end

function cfs:init_world()
    cluster_buffers.light_info.handle = ilight.light_buffer()
    --render
    update_scene_render_param()

    --build
    local be = world:entity(CLUSTER_BUILDAABB_EID, "dispatch:in")
    local bmi = be.dispatch.material
    bmi.b_cluster_AABBs = cluster_buffers.AABB.handle

    --cull
    local ce = world:entity(CLUSTER_LIGHTCULL_EID, "dispatch:in")
    local cmi = ce.dispatch.material
    cmi.b_cluster_AABBs             = cluster_buffers.AABB.handle
    cmi.b_light_grids_write         = cluster_buffers.light_grids.handle
    cmi.b_light_index_lists_write   = cluster_buffers.light_index_lists.handle
    cmi.b_light_info_for_cull       = cluster_buffers.light_info.handle

    --TODO: did we really need this buffer for thread sync ??
    --cmi.b_global_index_count        = create_buffer_property(cluster_buffers.global_index_count,   "cull")
end

local function cull_lights(viewid)
    if irq.main_camera_changed() then
        local e = world:entity(CLUSTER_LIGHTCULL_EID, "dispatch:in")
        icompute.dispatch(viewid, e.dispatch)
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
        local num_depth_slices = CLUSTER_SIZE[3]
        local log_farnear   = math.log(far/near, 2)
        local log_near      = math.log(near, 2)
    
        local mq = w:first "main_queue render_target:in"
        local vr = mq.render_target.view_rect
    
        imaterial.system_attrib_update("u_cluster_shading_param", math3d.vector(
            num_depth_slices / log_farnear, -num_depth_slices * log_near / log_farnear,
            vr.w / CLUSTER_SIZE[1], vr.h/CLUSTER_SIZE[2]))

        local be = world:entity(CLUSTER_BUILDAABB_EID, "dispatch:in")
        --no invz, no infinite far, could not use C.camera.projmat
        be.dispatch.material["u_normal_inv_proj"] = math3d.inverse(math3d.projmat(C.camera.frustum))
        icompute.dispatch(main_viewid, be.dispatch)
    end
end

function cfs:render_preprocess()
    check_rebuild_cluster_aabb()
    cull_lights(main_viewid)
end
