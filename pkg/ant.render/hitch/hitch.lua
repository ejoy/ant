local ecs   = ...
local world = ecs.world
local w     = world.w
local icompute  = ecs.require "ant.render|compute.compute"
local math3d    = require "math3d"
local mc        = import_package "ant.math".constant
local ig        = ecs.require "ant.group|group"
local Q         = world:clibs "render.queue"
local ivs       = ecs.require "ant.render|visible_state"
local hwi       = import_package "ant.hwi"
local idi       = ecs.require "ant.render|draw_indirect.draw_indirect"
local queuemgr  = ecs.require "ant.render|queue_mgr"
local cs_material = "/pkg/vaststars.resources/materials/hitch/hitch_compute.material"

local HITCHS = setmetatable({}, {__index=function(t, gid)
    local gg = {}
    t[gid] = gg
    return gg
end})

local DIRTY_GROUPS, GLBS, GROUP_VISIBLE = {}, {}, {}

local h = ecs.component "hitch"
function h.init(hh)
    assert(hh.group ~= nil)
    hh.visible_idx  = 0xffffffff
    hh.cull_idx     = 0xffffffff
    return hh
end

local main_viewid<const> = hwi.viewid_get "main_view"
local hitch_sys = ecs.system "hitch_system"

local function get_hitch_worldmat(e)
    return e.scene.worldmat
end

local function get_draw_num(hitchs)
    local draw_num = 0
    for _, _ in pairs(hitchs) do
        draw_num = draw_num + 1
    end
    return draw_num
end

local function get_hitch_worldmats_instance_memory(hitchs)
    local memory = {}
    for heid, _ in pairs(hitchs) do
        local e<close> = world:entity(heid, "scene:in")
        if e then
            local wm = get_hitch_worldmat(e)
            wm = math3d.transpose(wm)
            local c1, c2, c3 = math3d.index(wm, 1, 2, 3)
            memory[#memory+1] = ("%s%s%s"):format(math3d.serialize(c1), math3d.serialize(c2), math3d.serialize(c3))  
        end
    end
    return table.concat(memory, "")
end

local function dispatch_instance_buffer(e, diid, draw_num)

    local function to_dispath_num(indirectnum)
        return (indirectnum+63) // 64
    end

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

local function update_group_instance_buffer(gid)
    local glbs, hitchs = GLBS[gid], HITCHS[gid]
    local draw_num = get_draw_num(hitchs)
    local memory = get_hitch_worldmats_instance_memory(hitchs)

    local function update_instance_buffer(diid)
        local e = world:entity(diid, "draw_indirect:update")
        idi.update_instance_buffer(e, memory, draw_num)
    end

    local function update_buffer_and_dispatch(diid, cid)
        update_instance_buffer(diid)
        dispatch_instance_buffer(world:entity(cid, "dispatch:update"), diid, draw_num)
    end

    for _, glb in ipairs(glbs) do
        local diid, cid = glb.diid, glb.cid
        update_buffer_and_dispatch(diid, cid) 
    end
end

local function create_draw_indirect_and_compute_entity(glbs, gid)
    local hitchs = HITCHS[gid]
    local draw_num = get_draw_num(hitchs)
    local memory = get_hitch_worldmats_instance_memory(hitchs)
    for _, glb in ipairs(glbs) do
        glb.mesh.bounding = nil
        local diid = world:create_entity {
            --group = gid,
            policy = {
                "ant.render|simplerender",
                "ant.render|draw_indirect",
            },
            data = {
                scene = {
                    parent = glb.parent
                },
                simplemesh  = glb.mesh,
                material    = glb.material,
                visible_state = "main_view|selectable|cast_shadow",
                render_layer = glb.render_layer,
                --render_layer = "opacity",
                draw_indirect = {
                    instance_buffer = {
                        memory  = memory,
                        flag    = "ra",
                        layout  = "t45NIf|t46NIf|t47NIf",
                        num     = draw_num,
                        params  = {draw_num, 0, 0, glb.mesh.ib.num},
                    },
                },
            },
        }
        local cid = world:create_entity{
            policy = {
                "ant.render|compute",
            },
            data = {
                material = cs_material,
                dispatch = {
                    size = {((draw_num+63)//64), 1, 1},
                },
                on_ready = function (e)
                    w:extend(e, "dispatch:update")
                    dispatch_instance_buffer(e, diid, draw_num)
                end
            }
        }
        glb.diid, glb.cid = diid, cid
    end
end

local function set_dirty_hitch_group(hitch, hid, state)
    local gid = hitch.group
    DIRTY_GROUPS[gid] = true
    local hitchs = HITCHS[gid]
    hitchs[hid] = state
end

function hitch_sys:component_init()
    for e in w:select "INIT hitch:update" do
        local ho = e.hitch
        ho.visible_idx = Q.alloc()
        ho.cull_idx = Q.alloc()
    end
end

function hitch_sys:entity_remove()
    for e in w:select "REMOVED hitch:in hitch_update?out eid:in" do
        local ho = e.hitch
        Q.dealloc(ho.visible_idx)
        Q.dealloc(ho.cull_idx)
        set_dirty_hitch_group(e.hitch, e.eid)
        e.hitch_update = true
    end
end

function hitch_sys:entity_init()
    for e in w:select "INIT hitch:in hitch_create?out hitch_update?out view_visible?in hitch_visible?out" do
        e.hitch_create = true
        e.hitch_update = true
        e.hitch_visible = e.view_visible
    end 
end

function hitch_sys:follow_scene_update()
    for e in w:select "hitch scene_changed hitch_update?out" do
        e.hitch_update = true
    end  
end

function hitch_sys:finish_scene_update()
    if not w:check "hitch_create" then
        return
    end

    local groups = setmetatable({}, {__index=function(t, gid)
        local gg = {}
        t[gid] = gg
        return gg
    end})

    for e in w:select "hitch_create hitch:in eid:in" do
        local group = groups[e.hitch.group]
        group[#group+1] = e.eid
    end

    for gid, hitchs in pairs(groups) do
        ig.enable(gid, "hitch_tag", true)
        local h_aabb = math3d.aabb()
        for re in w:select "hitch_tag bounding:in skinning?in dynamic_mesh?in hitch_indirect?out" do
            if mc.NULL ~= re.bounding.aabb then
                h_aabb = math3d.aabb_merge(h_aabb, re.bounding.aabb)
                if re.skinning or re.dynamic_mesh then
                    GROUP_VISIBLE[gid] = true
                else
                    ivs.set_state(re, "main_view", false)
                    ivs.set_state(re, "cast_shadow", false)
                    re.hitch_indirect = true
                end
            end
        end
        ig.enable(gid, "hitch_tag", false)
        if math3d.aabb_isvalid(h_aabb) then
            for _, heid in ipairs(hitchs) do
                local e<close> = world:entity(heid, "hitch:in hitch_visible?out bounding:update scene_needchange?out")
                math3d.unmark(e.bounding.aabb)
                e.scene_needchange = true
                e.bounding.aabb = math3d.mark(h_aabb)
                --e.hitch_visible = GROUP_VISIBLE[e.hitch.group]
            end
        end
    end
    w:clear "hitch_create"
end

local function obj_visible(obj, queue_index)
	return Q.check(obj.visible_idx, queue_index) and (not Q.check(obj.cull_idx, queue_index))
end

function hitch_sys:render_preprocess()
    for e in w:select "hitch_update hitch:in eid:in" do
        if not GROUP_VISIBLE[e.hitch.group] then
            local mainmask = queuemgr.queue_mask "main_queue"
            local is_visible = obj_visible(e.hitch, mainmask)
            set_dirty_hitch_group(e.hitch, e.eid, is_visible) 
        end
    end
    for gid, _ in pairs(DIRTY_GROUPS) do
        if GLBS[gid] then
            update_group_instance_buffer(gid)
        else
            local glbs = {}
            ig.enable(gid, "hitch_tag", true)
            for re in w:select "hitch_tag eid:in mesh?in material?in render_layer?in scene?in" do
               if re.mesh then
                    glbs[#glbs+1] = {mesh = re.mesh, material = re.material, render_layer = re.render_layer, parent = re.eid}
               end
            end

            create_draw_indirect_and_compute_entity(glbs, gid)
            GLBS[gid] = glbs
            
            ig.enable(gid, "hitch_tag", false)
        end
    end

    DIRTY_GROUPS = {}
    w:clear "hitch_update"
end

