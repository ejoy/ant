local ecs   = ...
local world = ecs.world
local w     = world.w
local icompute  = ecs.require "ant.render|compute.compute"
local math3d    = require "math3d"
local mathpkg   = import_package "ant.math"
local mc, mu    = mathpkg.constant, mathpkg.util
local ig        = ecs.require "ant.group|group"
local irq       = ecs.require "render_system.renderqueue"
local Q         = world:clibs "render.queue"
local ivs       = ecs.require "ant.render|visible_state"
local hwi       = import_package "ant.hwi"
local idi       = ecs.require "ant.render|draw_indirect.draw_indirect"
local queuemgr  = ecs.require "ant.render|queue_mgr"
local cs_material = "/pkg/ant.resources/materials/hitch/hitch_compute.material"
local assetmgr  = import_package "ant.asset"

local GID_MT<const> = {__index=function(t, gid) local gg = {}; t[gid] = gg; return gg; end}

local INDIRECT_DRAW_GROUPS = setmetatable({}, GID_MT)
local DIRTY_GROUPS, DIRECT_DRAW_GROUPS = {}, {}
local HITCH_MAPS = {}
local HITCH_CULL = {}
local h = ecs.component "hitch"
function h.init(hh)
    assert(hh.group ~= nil)
    hh.visible_idx  = 0xffffffff
    hh.cull_idx     = 0xffffffff
    return hh
end

local main_viewid<const> = hwi.viewid_get "main_view"
local hitch_sys = ecs.system "hitch_system"

local function get_hitch_worldmats_instance_memory(hitchs)
    local memory = {}
    for heid in pairs(hitchs) do
        local e<close> = world:entity(heid, "scene:in")
        local c1, c2, c3 = math3d.index(math3d.transpose(e.scene.worldmat), 1, 2, 3)
        memory[#memory+1] = ("%s%s%s"):format(math3d.serialize(c1), math3d.serialize(c2), math3d.serialize(c3))
    end
    return table.concat(memory, ""), #memory
end

local function to_dispath_num(indirectnum)
    return (indirectnum+63) // 64
end

local function dispatch_instance_buffer(e, diid, draw_num)
    local die = world:entity(diid, "draw_indirect:in")
    local di = die.draw_indirect

   assert(di.instance_buffer.num == draw_num)
    if draw_num > 0 then
        local dis = e.dispatch
        dis.size[1] = to_dispath_num(draw_num)
        local m = dis.material
        di.instance_buffer.params[1] = draw_num
        m.u_mesh_params = math3d.vector(di.instance_buffer.params)
        m.b_indirect_buffer = {
            type = "b",
            access = "w",
            value = di.handle,
            stage = 0,
        }
        icompute.dispatch(main_viewid, dis)
    end
end

local function update_instance_buffer(diid, memory, draw_num)
    local e = world:entity(diid, "draw_indirect:update")
    idi.update_instance_buffer(e, memory, draw_num)
end

local function update_group_instance_buffer(indirect_draw_group)
    local glbs, hitchs = indirect_draw_group.glbs, indirect_draw_group.hitchs
    local memory, draw_num = get_hitch_worldmats_instance_memory(hitchs)

    local function update_buffer_and_dispatch(diid, cid)
        update_instance_buffer(diid, memory, draw_num)
        dispatch_instance_buffer(world:entity(cid, "dispatch:update"), diid, draw_num)
    end

    for _, glb in ipairs(glbs) do
        local diid, cid = glb.diid, glb.cid
        update_buffer_and_dispatch(diid, cid) 
    end
end

local function create_compute_entity(glbs, memory, draw_num)
    for _, glb in ipairs(glbs) do
        local diid = glb.diid
        local die = world:entity(diid, "draw_indirect:update mesh_result:in")
        idi.update_instance_buffer(die, memory, draw_num)
        die.draw_indirect.instance_buffer.params =  {draw_num, 0, 0, die.mesh_result.ib.num}
        w:submit(die)
        local cid = world:create_entity{
            policy = {
                "ant.render|compute",
            },
            data = {
                material = cs_material,
                dispatch = {
                    size = {1, 1, 1},   --update on dispatch_instance_buffer
                },
                on_ready = function (e)
                    w:extend(e, "dispatch:update")
                    --TODO: this compute shader should not mark
                    assetmgr.material_mark(e.dispatch.fx.prog)
                    dispatch_instance_buffer(e, diid, draw_num)
                end
            }
        }
        glb.cid = cid
    end
end

local function set_dirty_hitch_group(hitch, hid, state)
    if DIRECT_DRAW_GROUPS[hitch.group] then
        return
    end
    local gid = hitch.group
    DIRTY_GROUPS[gid] = true
    local indirect_draw_group = INDIRECT_DRAW_GROUPS[gid]

    local old_gid = HITCH_MAPS[hid]
    if old_gid and old_gid ~= gid then
        local old_indirect_draw_group = INDIRECT_DRAW_GROUPS[old_gid]
        old_indirect_draw_group.hitchs[hid] = nil
        DIRTY_GROUPS[old_gid] = true
    end
    HITCH_MAPS[hid] = gid

    if not indirect_draw_group.hitchs then
        indirect_draw_group.hitchs = {}
    end
    indirect_draw_group.hitchs[hid] = state
end

function hitch_sys:component_init()
    for e in w:select "INIT hitch:update" do
        local ho = e.hitch
        ho.visible_idx = Q.alloc()
        ho.cull_idx = Q.alloc()
    end
end

function hitch_sys:entity_remove()
    for e in w:select "REMOVED hitch:in eid:in" do
        local ho = e.hitch
        Q.dealloc(ho.visible_idx)
        Q.dealloc(ho.cull_idx)
        set_dirty_hitch_group(e.hitch, e.eid)
    end
end

function hitch_sys:entity_init()
    for e in w:select "INIT hitch:in view_visible?in hitch_visible?out" do
        e.hitch_visible = e.view_visible
    end 
end

function hitch_sys:follow_scene_update()
    for e in w:select "scene_changed hitch hitch_update?out" do
        e.hitch_update = true
    end
end

function hitch_sys:finish_scene_update()
    if not w:check "hitch_create" then
        return
    end

    local groups = setmetatable({}, GID_MT)
    for e in w:select "hitch_create hitch:in eid:in" do
        local group = groups[e.hitch.group]
        group[#group+1] = e.eid
    end

    for gid, hitchs in pairs(groups) do
        ig.enable(gid, "hitch_tag", true)
        -- draw instance in render_submit
        --ig.enable(gid, "view_visible", true)
        local objaabb = math3d.aabb()
        for re in w:select "hitch_tag bounding:in skinning?in dynamic_mesh?in" do
            if re.skinning or re.dynamic_mesh  then
                DIRECT_DRAW_GROUPS[gid] = true
                --ig.enable(gid, "view_visible", false)
            end

            if re.bounding.scene_aabb ~= mc.NULL then
                objaabb = math3d.aabb_merge(objaabb, re.bounding.scene_aabb)
            end
        end
        ig.enable(gid, "hitch_tag", false)
        for _, heid in ipairs(hitchs) do
            local he<close> = world:entity(heid, "hitch:in eid:in bounding:update scene:in scene_needchange?out")
            set_dirty_hitch_group(he.hitch, he.eid, true)
            HITCH_CULL[heid] = false
            he.scene_needchange = true

            if math3d.aabb_isvalid(objaabb) then
                he.bounding.aabb       = mu.M3D_mark(he.bounding.aabb, objaabb)
                he.bounding.scene_aabb = mu.M3D_mark(he.bounding.scene_aabb, math3d.aabb_transform(he.scene.worldmat, objaabb))
            end
        end
    end
    w:clear "hitch_create"
end


function hitch_sys:refine_camera()
    -- remove hitch / hitch scene_update / reset hitch group
    for e in w:select "hitch_update hitch:in eid:in view_visible?in" do
        set_dirty_hitch_group(e.hitch, e.eid, e.view_visible)
    end
    if irq.main_camera_changed() then
        for e in w:select "hitch:in eid:in view_visible?in" do
            local is_culled = not e.view_visible
            if HITCH_CULL[e.eid] ~= is_culled then
                HITCH_CULL[e.eid] = is_culled
                set_dirty_hitch_group(e.hitch, e.eid, e.view_visible) 
            end
        end        
    end

    for gid in pairs(DIRTY_GROUPS) do
        ig.enable(gid, "view_visible", true)
        local indirect_draw_group = INDIRECT_DRAW_GROUPS[gid]
        if indirect_draw_group.glbs then
            update_group_instance_buffer(indirect_draw_group)
        else
            ig.enable(gid, "hitch_tag", true)
            
            local memory, draw_num = get_hitch_worldmats_instance_memory(indirect_draw_group.hitchs)
            local glbs = {}
            for re in w:select "hitch_tag mesh_result draw_indirect eid:in render_object_visible?update bounding?update" do
                -- render_object_visible only set in render_system entity_init by view_visible
                re.render_object_visible = true
                re.bounding.aabb       = mu.M3D_mark(re.bounding.aabb, math3d.aabb())
                re.bounding.scene_aabb = mu.M3D_mark(re.bounding.scene_aabb, math3d.aabb())
                glbs[#glbs+1] = { diid = re.eid}
                update_instance_buffer(re.eid, memory, draw_num)
            end
            for re in w:select "hitch_tag efk render_object_visible?update view_visible?update" do
                ivs.set_state(re, "efk_queue", true)
            end
            indirect_draw_group.glbs = glbs
            create_compute_entity(indirect_draw_group.glbs, memory, draw_num)

            ig.enable(gid, "hitch_tag", false)
        end
    end

    DIRTY_GROUPS = {}
    w:clear "hitch_update"
end


