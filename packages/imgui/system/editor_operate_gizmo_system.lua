local ecs = ...
local world = ecs.world
local math3d = require "math3d"
local mathpkg = require "ant.math"
local mu, mc = mathpkg.util, mathpkg.constant
local renderpkg = import_package "ant.render"
local camerautil= renderpkg.camera

local util = require "system.editor_system_util"
local WatcherEvent = require "hub_event"

local show_operate_gizmo = ecs.tag "show_operate_gizmo"
local gizmo_object = ecs.component "gizmo_object"
    ["opt"].type "string"   --"position"/"rotation"/"scale"
    ["opt"].dir "string"    --"x"/"y"/"z"  *"xy"/"yz"/"xz"

local policy_gizmo_object = ecs.policy "gizmo_object"
policy_gizmo_object.require_component "gizmo_object"
--local transform_watcher = world:sub {"transform_changed", "transform"}

local GizmoType = {"position","rotation","scale"}
local GizmoDirection = {"x","y","z"}

ecs.component "operate_gizmo_cache" {}
ecs.singleton "operate_gizmo_cache" {
    last_target_eid = nil,
    picked_dir = nil, -- "x"/"y","z", not supported yet:("xy","xz","yz")
    picked_type = nil, -- "position"/"ratation","scale", not supported yet:("xy","xz","yz")
    last_mouse_pos = nil,
    mouse_delta = nil,
    gizmo_type = "position",
    gizmo = nil,
    cur_mouse_state = "UP",
    is_scale_draging = false,
    is_rotation_draging = false,
    -- count = {0,0},
    -- move_count = {0,0,0},
}

local function update_transform(eid, transform, field, value)
    local srt = transform.srt
    local oldvalue = srt.t
    srt.t = value
    world:pub {"component_changed", "transform", eid,
        {field = field, oldvalue = oldvalue, newvalue=value}
    }
end

local function scale_gizmo_to_normal(gizmo_eid)
    local gizmo = world[gizmo_eid]
    local et = gizmo.transform
    if et.parent then
        local camera = camerautil.main_queue_camera(world)
        local vp = mu:view_proj(camera)
        local tvp  = math3d.totable(math3d.transform(vp, et.srt.t))

        local scale = math.abs(tvp[4]/7)
        local parent_e = world[et.parent]
        local finalscale = math3d.mul(scale, parent_e.transform.srt.s)
        update_transform(gizmo_eid, et, "s", finalscale)
    end
end

local function pos_to_screen(pos,trans,viewproj,w,h)
    --[[
        vec4_WS = trans.wrold * vec4        --> *
        vec4_proj= viewproj * vec4          |   --> %
        vec4_NDC = vec4_proj / vec4_proj.w  |

        vec4_map = (vec4_NDC + 1) * 0.5  |--> +*  transform from [-1, 1] ==>[0, 1]
        vec4_screen = vec4_map.xy * wh   |
    ]]

    local vec4 = math3d.mul(pos, math3d.reciprocal(trans.s))
    local posNDC = math3d.transformH(math3d.mul(viewproj, trans.world), vec4)

    return math3d.mul(
            math3d.add(posNDC, {1, 1, 0, 0}),
            {0.5 * w, 0.5 * h, 0, 0})
end

local function calc_drag_axis_unit(trans, viewproj, axis_unit, w, h, dx, dy)
    local r_axis_unit = math3d.transform(trans.r, axis_unit)
    local screen_pos0 = pos_to_screen(mc.ZERO_PT,trans,viewproj,w,h)
    local screen_pos1 = pos_to_screen(axis_unit,trans,viewproj,w,h)
    local screen_unit = math3d.sub(screen_pos1, screen_pos0)
    local normalize_sceen_unit = math3d.normalize(screen_unit)
    local sceen_unit_dis = math3d.length(screen_unit)
    local effect_dis = math3d.dot({dx, dy, 0, 0}, normalize_sceen_unit)

    return math3d.mul(r_axis_unit, effect_dis/sceen_unit_dis)
end

local function gizmo_position_on_drag(cache,picked_type,mouse_delta)
    local target_entity_id = world:singleton_entity_id("show_operate_gizmo")
    local target_entity = target_entity_id and world[target_entity_id]
    --assert(target_entity)
    if target_entity then
        local typ = picked_type --"x","y","z"
        local axis_unit = cache.axis_map[typ] -- {1,0,0} or {0,1,0} or {0,0,1}
        local dx,dy = mouse_delta[1],mouse_delta[2]
        -- log("dxdy",dx,dy)
        --calc part1
        local mq = world:singleton_entity "main_queue"
        local camera = world[mq.camera_eid].camera

        -- log.info_a("mq",mq)
        local viewproj = mu.view_proj(camera)
        local vp_rect = mq.render_target.viewport.rect
        local trans = target_entity.transform
        local drag_axis_unit = calc_drag_axis_unit(trans, viewproj, axis_unit, vp_rect.w. vp_rect.h, dx, dy)
        local new_pos = math3d.add(drag_axis_unit, trans.t)
        update_transform(target_entity_id, target_entity.transform, "t", new_pos)
        -- update_world(trans)
    end
end

local function add_gizmo_scale_length(scale_object, picked_dir, tvec3)
    local scale_box_id = scale_object["box_"..picked_dir]
    local scale_box = world[scale_box_id]
    local scale_line_id = scale_object["line_"..picked_dir]
    local scale_line= world[scale_line_id]

    local sbtran = scale_box.transform
    local newpos = math3d.add(sbtran.t, tvec3)
    update_transform(scale_box_id, sbtran, "t", newpos)
    update_transform(scale_line_id, scale_line, "s", math3d.mul(newpos, 1 / scale_object.line_length))
end

local function gizmo_scale_on_release(cache)
    local picked_dir = cache.is_scale_draging
    assert(picked_dir)

    local axis_unit = cache.axis_map[picked_dir]

    local scale_object = cache.gizmo.scale
    local scale_box_id = scale_object["box_"..picked_dir]
    local scale_box = world[scale_box_id]
    local pos = math3d.mul(axis_unit, scale_object.line_length)
    
    update_transform(scale_box_id, scale_box.transform, "t", pos)

    local scale_line_id = scale_object["line_"..picked_dir]
    local scale_line= world[scale_line_id]
    update_transform(scale_line_id, scale_line.transform, "s", axis_unit)
end

local function gizmo_scale_on_drag(cache,picked_dir,mouse_delta)
    local scale_object = cache.gizmo.scale
    local target_entity_id = world:singleton_entity_id("show_operate_gizmo")
    local target_entity = target_entity_id and world[target_entity_id]
    --assert(target_entity)
    if target_entity then
        -- log.info_a("mouse_delta:",mouse_delta)
        local dx,dy = mouse_delta[1],mouse_delta[2]
        local scale_box_id = scale_object["box_"..picked_dir]
        local scale_box = world[scale_box_id]
        local scale_box_trans =  scale_box.transform
        local axis_unit = cache.axis_map[picked_dir] -- {1,0,0} or {0,1,0} or {0,0,1}
        
        local mq = world:singleton_entity "main_queue"
        local camera = world[mq.camera_eid].camera
        local viewproj = mu.view_proj(camera)
        local vp_rect = mq.render_target.viewport.rect

        local tvec3 = calc_drag_axis_unit(scale_box_trans, viewproj, axis_unit, vp_rect.w, vp_rect.h, dx, dy)
        add_gizmo_scale_length(scale_object, picked_dir, tvec3)

        local scale_add = math3d.mul(tvec3, 1 / scale_object.line_length)
        local trans = target_entity.transform

        local newscale = math3d.mul(trans.s, math3d.add(scale_add, {1, 1, 1, 0}))
        update_transform(target_entity_id, trans, "s", newscale)
    end
end

local function gizmo_rotation_on_drag(cache,picked_type,mouse_delta)
    --旋转轴被自己的矩阵变化了
    local function world_to_model(point, model_srt)
        return math3d.transform(math3d.inverse(model_srt), point, 1)
    end
    local target_entity_id = world:singleton_entity_id("show_operate_gizmo")
    local target_entity = target_entity_id and world[target_entity_id]
    if target_entity then
        local trans = target_entity.transform
        local normalize_sceen_unit = nil
        local sceen_unit_dis = nil
        local dx,dy = mouse_delta[1],mouse_delta[2]
        local r_axis_unit = nil
        if cache.last_rotation then
            -- log.info("last_rotation",cache.last_rotation)
            normalize_sceen_unit = cache.last_rotation.normalize_sceen_unit
            sceen_unit_dis = cache.last_rotation.sceen_unit_dis
            r_axis_unit = cache.last_rotation.r_axis_unit
        else
            -- log.info("picked_type",picked_type)
            local typ = picked_type
            local axis_unit = cache.axis_map[typ]
            local rot_unit = cache.rot_axis_map[typ]
            local mq = world:singleton_entity "main_queue"
            local camera = world[mq.camera_eid].camera

            local viewproj = mu.view_proj(camera)
            r_axis_unit = math3d.transform(trans.r, axis_unit)
            ------------------------
            local inject_pos_world
            do 
                local gizmo_eid = cache.gizmo.eid
                local gizmo_trans = world[gizmo_eid].transform
                local gizmo_world = gizmo_trans.world
                local point_world = gizmo_world.t
                local axis_unitWS = math3d.transform(gizmo_world, axis_unit, 1)
                local normalWS = math3d.normalize(math3d.sub(point_world, axis_unitWS))
                assert(cache.mouse_pos)
                local click_pos = util.mouse_project_onto_plane(world,cache.mouse_pos,point_world,normalWS)
                inject_pos_world = math3d.add(point_world, math3d.normalize(math3d.sub(click_pos,point_world)))
            end
            ------------------------
            local click_in_model = world_to_model(inject_pos_world, trans.world)
            local click_in_model_roted = math3d.transform(math3d.quaternion(rot_unit), click_in_model)
            local vp_rt = mq.render_target.viewport.rect
            local w,h = vp_rt.w, vp_rt.h
            local screen_pos0 = pos_to_screen(click_in_model, trans,viewproj,w,h)
            local screen_pos1 = pos_to_screen(click_in_model_roted,trans,viewproj,w,h)
            local screen_unit = math3d.sub(screen_pos1, screen_pos0)
            normalize_sceen_unit =  math3d.normalize(screen_unit)
            sceen_unit_dis = math3d.length(screen_unit)
            cache.last_rotation = {
                normalize_sceen_unit = normalize_sceen_unit,
                sceen_unit_dis = sceen_unit_dis,
                r_axis_unit = r_axis_unit,
            }
        end
        local effect_dis = math3d.dot({dx, dy, 0}, normalize_sceen_unit)
        local t = effect_dis/sceen_unit_dis
        local new_rot = math3d.mul(math3d.quaternion{axis=r_axis_unit, r=0.01*t}, trans.r)
        update_transform(target_entity_id, trans, "r", new_rot)
    end
end

local function gizmo_rotation_on_release(cache)
    -- log.info("gizmo_rotation_on_release",cache.last_rotation)
    cache.last_rotation = nil
end

local function on_gizmo_type_change(self,typ)
    local operate_gizmo_cache = world:singleton "operate_gizmo_cache"
    if typ ~= operate_gizmo_cache.gizmo_type then
        local gizmo = operate_gizmo_cache.gizmo
        local old_typ = operate_gizmo_cache.gizmo_type
        world[gizmo[old_typ].eid].hierarchy_visible = false
        world[gizmo[typ].eid].hierarchy_visible = true
        -- world:disable_tag(gizmo[old_typ].eid,"hierarchy_visible")
        -- world:enable_tag(gizmo[typ].eid,"hierarchy_visible")
        operate_gizmo_cache.gizmo_type = typ
    end

end

local mouse_left_mb = world:sub {"mouse","LEFT"}

local gizmo_sys =  ecs.system "editor_operate_gizmo_system"
gizmo_sys.require_singleton "operate_gizmo_cache"
function gizmo_sys:init()
    --create gizmo
    local operate_gizmo_cache = world:singleton "operate_gizmo_cache"
    assert(not operate_gizmo_cache.gizmo_eid)
    local gizmo = util.create_gizmo(world)
    for i,typ in ipairs(GizmoType) do
        local eid = gizmo[typ].eid
        if typ == operate_gizmo_cache.gizmo_type then
            -- world:enable_tag(eid,"hierarchy_visible")
            world[eid].hierarchy_visible = true
        else
            -- world:disable_tag(eid,"hierarchy_visible")
            world[eid].hierarchy_visible = false
        end
    end
    operate_gizmo_cache.gizmo = gizmo
    operate_gizmo_cache.axis_map = {
        x = {1,0,0},
        y = {0,1,0},
        z = {0,0,1},
    }
    operate_gizmo_cache.rot_axis_map = {
        x = {0.01,0,0},
        y = {0,0.01,0},
        z = {0,0,0.01},
    }
    operate_gizmo_cache.mouse_delta = {}
    local mouse_delta = operate_gizmo_cache.mouse_delta
    for _,typ in ipairs(GizmoType) do
        mouse_delta[typ] = {}
        for k,_ in pairs(operate_gizmo_cache.axis_map) do
            mouse_delta[typ][k] = {0,0}
        end
    end
    -------------------
    local hub = world.args.hub
    hub.subscribe(WatcherEvent.ETR.GizmoType,on_gizmo_type_change,self)
    --------------
    -- self.message.observers:add({
    --     mouse = function (_, x, y, what, state)
    --         if what == "LEFT" then
    --             -- local count = operate_gizmo_cache.count
    --             operate_gizmo_cache.cur_mouse_state = state
    --             if  ( state == "MOVE" or state == "DOWN" ) then
    --                 if state == "MOVE" and operate_gizmo_cache.last_mouse_pos then
    --                     local gizmo_type = operate_gizmo_cache.gizmo_type
    --                     local picked_dir = operate_gizmo_cache.picked_dir
    --                     if picked_dir then
    --                         local last_mouse_pos = operate_gizmo_cache.last_mouse_pos
    --                         local dx,dy = x-last_mouse_pos[1],(y-last_mouse_pos[2])*-1
    --                         -- 
    --                         local mouse_delta = operate_gizmo_cache.mouse_delta[gizmo_type][picked_dir]
    --                         mouse_delta[1] = mouse_delta[1] + dx
    --                         mouse_delta[2] = mouse_delta[2] + dy
    --                     end
    --                     -- count[1] = count[1] + (x-operate_gizmo_cache.last_mouse_pos[1])
    --                     -- count[2] = count[2] + (y-operate_gizmo_cache.last_mouse_pos[2])
    --                 else
    --                     operate_gizmo_cache.mouse_pos = {x, y}
    --                 end
    --                 operate_gizmo_cache.last_mouse_pos = {x,y}
    --             else
    --                 -- log.info_a("count",count)
    --                 -- log.info_a("move_count",operate_gizmo_cache.move_count)
    --                 -- count[1] = 0
    --                 -- count[2] = 0
    --                 -- operate_gizmo_cache.move_count[1] = 0
    --                 -- operate_gizmo_cache.move_count[2] = 0
    --                 -- operate_gizmo_cache.move_count[3] = 0
    --             end
    --         end
    --     end
    -- })

end

local function update_mouse_event()
    local operate_gizmo_cache = world:singleton "operate_gizmo_cache"
    for mouse_event in mouse_left_mb:each() do
        local _,what,state,x,y = table.unpack(mouse_event)
        operate_gizmo_cache.cur_mouse_state = state
        if  ( state == "MOVE" or state == "DOWN" ) then
            if state == "MOVE" and operate_gizmo_cache.last_mouse_pos then
                local gizmo_type = operate_gizmo_cache.gizmo_type
                local picked_dir = operate_gizmo_cache.picked_dir
                if picked_dir then
                    local last_mouse_pos = operate_gizmo_cache.last_mouse_pos
                    local dx,dy = x-last_mouse_pos[1],(y-last_mouse_pos[2])*-1
                    -- 
                    local mouse_delta = operate_gizmo_cache.mouse_delta[gizmo_type][picked_dir]
                    mouse_delta[1] = mouse_delta[1] + dx
                    mouse_delta[2] = mouse_delta[2] + dy
                end
                -- count[1] = count[1] + (x-operate_gizmo_cache.last_mouse_pos[1])
                -- count[2] = count[2] + (y-operate_gizmo_cache.last_mouse_pos[2])
            else
                operate_gizmo_cache.mouse_pos = {x, y}
            end
            operate_gizmo_cache.last_mouse_pos = {x,y}
        else
            -- log.info_a("count",count)
            -- log.info_a("move_count",operate_gizmo_cache.move_count)
            -- count[1] = 0
            -- count[2] = 0
            -- operate_gizmo_cache.move_count[1] = 0
            -- operate_gizmo_cache.move_count[2] = 0
            -- operate_gizmo_cache.move_count[3] = 0
        end
    end
end


function gizmo_sys:editor_update()
    update_mouse_event()
    local target_entity_id = world:singleton_entity_id("show_operate_gizmo")
    local target_entity = target_entity_id and world[target_entity_id]
    --sync transform gizmo
    local operate_gizmo_cache = world:singleton "operate_gizmo_cache"
    local gizmo_eid =  operate_gizmo_cache.gizmo.eid
    local gizmo_entity = world[gizmo_eid]
    if target_entity then
        if operate_gizmo_cache.last_target_eid ~= target_entity_id then
            gizmo_entity.transform.parent = target_entity_id
        end

        scale_gizmo_to_normal(gizmo_eid)

        if target_entity_id ~= operate_gizmo_cache.last_target_eid then
            -- world:disable_tag(gizmo_eid,"hierarchy_visible")
            world[gizmo_eid].hierarchy_visible = false
            operate_gizmo_cache.last_target_eid = target_entity_id
        elseif not gizmo_entity.hierarchy_visible then
            world[gizmo_eid].hierarchy_visible = true
            -- world:enable_tag(gizmo_eid,"hierarchy_visible")
        end
    else
        if operate_gizmo_cache.last_target_eid then
            -- world:disable_tag(gizmo_eid,"hierarchy_visible")
            world[gizmo_eid].hierarchy_visible = false
            operate_gizmo_cache.last_target_eid = nil
        end
    end
    --drag gizmo
    local mouse_delta = operate_gizmo_cache.mouse_delta
    for typ,dir_dic in pairs(mouse_delta) do
        for dir,v in pairs(dir_dic) do
            if v[1] ~=0 or v[2]~=0 then
                if typ == "position" then
                    gizmo_position_on_drag(operate_gizmo_cache,dir,v)
                elseif typ == "scale" then
                    gizmo_scale_on_drag(operate_gizmo_cache,dir,v)
                    operate_gizmo_cache.is_scale_draging = dir
                elseif typ == "rotation" then
                    gizmo_rotation_on_drag(operate_gizmo_cache,dir,v)
                    operate_gizmo_cache.is_rotation_draging = dir
                end
                v[1],v[2] = 0,0
            end
        end

    end
    if operate_gizmo_cache.cur_mouse_state == "UP" then
        if operate_gizmo_cache.is_scale_draging then
            gizmo_scale_on_release(operate_gizmo_cache)
            operate_gizmo_cache.is_scale_draging = nil
        elseif operate_gizmo_cache.is_rotation_draging then
            gizmo_rotation_on_release(operate_gizmo_cache)
            operate_gizmo_cache.is_rotation_draging = nil
        end
        operate_gizmo_cache.picked_dir = nil
    end
end

function gizmo_sys:after_pickup()
    local pickup_entity = world:singleton_entity "pickup"
    if pickup_entity then
        local picked_dir = nil
        local pickup_comp = pickup_entity.pickup
        local eid = pickup_comp.pickup_cache.last_pick
        if eid and world[eid] and world[eid].gizmo_object then
            picked_dir = world[eid].gizmo_object.dir
        end
        world:singleton "operate_gizmo_cache".picked_dir = picked_dir
    end
end

