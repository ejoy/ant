local ecs = ...
local world = ecs.world

local math3d = require "math3d"
local mathpkg = import_package "ant.math"
local mu, mc = mathpkg.util, mathpkg.constant
local renderpkg = import_package "ant.render"
local camerautil= renderpkg.camera

local util = require "editor_system_util"
local icamera = world:interface "ant.scene|camera"

local GizmoType = {"position","rotation","scale"}

local cache = {
    last_target_eid = nil,
    picked_dir = nil, -- "x"/"y","z", not supported yet:("xy","xz","yz")
    picked_type = nil, -- "position"/"ratation","scale", not supported yet:("xy","xz","yz")
    last_mouse_pos = nil,
    mouse_delta = nil,
    gizmo_type = "rotation",
    gizmo = nil,
    cur_mouse_state = "UP",
    is_scale_draging = false,
    is_rotation_draging = false,
    -- count = {0,0},
    -- move_count = {0,0,0},
}

local function update_transform(eid, transform, field, value)
    local oldvalue = transform[field]
    transform[field] = value
    world:pub {"component_changed", "transform", eid,
        {field = field, oldvalue = oldvalue, newvalue=value}
    }
end

local function scale_gizmo_to_normal(gizmo_eid)
    local gizmo = world[gizmo_eid]
    local et = gizmo.transform
    if et.parent then
        local camera = camerautil.main_queue_camera(world)
        local vp = mu.view_proj(camera)
        local tvp  = math3d.totable(math3d.transform(vp, et.t, 1))

        local scale = math.abs(tvp[4]/7)
        local parent_e = world[et.parent]
        local finalscale = math3d.mul(scale, parent_e.transform.s)
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

    local vec4 = math3d.mul(math3d.vector(pos), math3d.reciprocal(trans.s))
    local posNDC = math3d.transformH(math3d.mul(viewproj, trans._world), vec4)

    return math3d.mul(
            math3d.add(posNDC, {1, 1, 0, 0}),
            {0.5 * w, 0.5 * h, 0, 0})
end

local function calc_drag_axis_unit(trans, viewproj, axis_unit, w, h, dx, dy)
    local r_axis_unit = math3d.transform(trans.r, axis_unit, 0)
    local screen_pos0 = pos_to_screen(mc.ZERO_PT,trans,viewproj,w,h)
    local screen_pos1 = pos_to_screen(axis_unit,trans,viewproj,w,h)
    local screen_unit = math3d.sub(screen_pos1, screen_pos0)
    local normalize_sceen_unit = math3d.normalize(screen_unit)
    local sceen_unit_dis = math3d.length(screen_unit)
    local effect_dis = math3d.dot({dx, dy, 0, 0}, normalize_sceen_unit)

    return math3d.mul(r_axis_unit, effect_dis/sceen_unit_dis)
end

local function gizmo_position_on_drag(cache,picked_type,mouse_delta)
    for _, target_entity_id in world:each "show_operate_gizmo" do
        local target_entity = world[target_entity_id]
        local typ = picked_type --"x","y","z"
        local axis_unit = cache.axis_map[typ] -- {1,0,0} or {0,1,0} or {0,0,1}
        local dx,dy = mouse_delta[1],mouse_delta[2]
        -- log("dxdy",dx,dy)
        --calc part1
        local mq = world:singleton_entity "main_queue"
        local viewproj = icamera.viewproj(mq.camera_eid)
        local vp_rect = mq.render_target.viewport.rect
        local trans = target_entity.transform
        local drag_axis_unit = calc_drag_axis_unit(trans, viewproj, axis_unit, vp_rect.w, vp_rect.h, dx, dy)
        local new_pos = math3d.add(drag_axis_unit, trans.t)
        update_transform(target_entity_id, target_entity.transform, "t", new_pos)
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
    update_transform(scale_line_id, scale_line.transform, "s", math3d.mul(newpos, 1 / scale_object.line_length))
end

local function gizmo_scale_on_release(cache)
    local picked_dir = cache.is_scale_draging
    assert(picked_dir)

    local axis_unit = cache.axis_map[picked_dir]

    local scale_object = cache.gizmo.scale
    local scale_box_id = scale_object["box_"..picked_dir]
    local scale_box = world[scale_box_id]
    local pos = math3d.mul(math3d.vector(axis_unit), scale_object.line_length)

    update_transform(scale_box_id, scale_box.transform, "t", pos)

    local scale_line_id = scale_object["line_"..picked_dir]
    local scale_line= world[scale_line_id]
    update_transform(scale_line_id, scale_line.transform, "s", axis_unit)
end

local function gizmo_scale_on_drag(cache,picked_dir,mouse_delta)
    local scale_object = cache.gizmo.scale
    for _, target_entity_id in world:each "show_operate_gizmo" do
        local target_entity = world[target_entity_id]
        local dx,dy = mouse_delta[1],mouse_delta[2]
        local scale_box_id = scale_object["box_"..picked_dir]
        local scale_box = world[scale_box_id]
        local scale_box_trans =  scale_box.transform
        local axis_unit = cache.axis_map[picked_dir] -- {1,0,0} or {0,1,0} or {0,0,1}
        
        local mq = world:singleton_entity "main_queue"
        local viewproj = icamera.viewproj(mq.camera_eid)
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
    for _, target_entity_id in world:each "show_operate_gizmo" do
        local target_entity = world[target_entity_id]
        local trans = target_entity.transform
        local normalize_sceen_unit = nil
        local sceen_unit_dis = nil
        local dx,dy = mouse_delta[1],mouse_delta[2]
        local r_axis_unit = nil
        if cache.last_rotation then
            normalize_sceen_unit = cache.last_rotation.normalize_sceen_unit
            sceen_unit_dis = cache.last_rotation.sceen_unit_dis
            r_axis_unit = cache.last_rotation.r_axis_unit
        else
            local typ = picked_type
            local axis_unit = cache.axis_map[typ]
            local rot_unit = cache.rot_axis_map[typ]
            local mq = world:singleton_entity "main_queue"
            local viewproj = icamera.viewproj(mq.camera_eid)
            r_axis_unit = math3d.transform(trans.r, axis_unit, 0)
            ------------------------
            local inject_pos_world
            do 
                local gizmo_eid = cache.gizmo.eid
                local gizmo_trans = world[gizmo_eid].transform
                local gizmo_world = gizmo_trans._world
                local point_world = gizmo_world.t
                local axis_unitWS = math3d.transform(gizmo_world, axis_unit, 1)
                local normalWS = math3d.normalize(math3d.sub(point_world, axis_unitWS))
                assert(cache.mouse_pos)
                local click_pos = util.mouse_project_onto_plane(world,cache.mouse_pos,point_world,normalWS)
                inject_pos_world = math3d.add(point_world, math3d.normalize(math3d.sub(click_pos,point_world)))
            end
            ------------------------
            local click_in_model = world_to_model(inject_pos_world, trans._world)
            local click_in_model_roted = math3d.transform(math3d.quaternion(rot_unit), click_in_model, 0)
            local vp_rt = mq.render_target.viewport.rect
            local w,h = vp_rt.w, vp_rt.h
            local screen_pos0 = pos_to_screen(click_in_model, trans,viewproj,w,h)
            local screen_pos1 = pos_to_screen(click_in_model_roted,trans,viewproj,w,h)
            local screen_unit = math3d.sub(screen_pos1, screen_pos0)
            normalize_sceen_unit =  math3d.normalize(screen_unit)
            sceen_unit_dis = math3d.length(screen_unit)
            cache.last_rotation = {
                normalize_sceen_unit = math3d.ref(normalize_sceen_unit),
                sceen_unit_dis = sceen_unit_dis,
                r_axis_unit = math3d.ref(r_axis_unit),
            }
        end
        local effect_dis = math3d.dot(math3d.vector(dx, dy, 0), normalize_sceen_unit)
        local t = effect_dis/sceen_unit_dis
        local new_rot = math3d.mul(math3d.quaternion{axis=r_axis_unit, r=0.01*t}, trans.r)
        update_transform(target_entity_id, trans, "r", new_rot)
    end
end

local function gizmo_rotation_on_release(cache)
    cache.last_rotation = nil
end

local mouse_left_mb = world:sub {"mouse","LEFT"}

local editor_operate_gizmo_sys =  ecs.system "editor_operate_gizmo_system"

function editor_operate_gizmo_sys:init()
    --create gizmo
    assert(not cache.gizmo_eid)
    local gizmo = util.create_gizmo(world)
    for i,typ in ipairs(GizmoType) do
        local eid = gizmo[typ].eid
        if typ == cache.gizmo_type then
            world:enable_tag(eid,"hierarchy_visible")
        else
            world:disable_tag(eid,"hierarchy_visible")
        end
    end
    cache.gizmo = gizmo
    cache.axis_map = {
        x = {1,0,0},
        y = {0,1,0},
        z = {0,0,1},
    }
    cache.rot_axis_map = {
        x = {0.01,0,0},
        y = {0,0.01,0},
        z = {0,0,0.01},
    }
    cache.mouse_delta = {}
    local mouse_delta = cache.mouse_delta
    for _,typ in ipairs(GizmoType) do
        mouse_delta[typ] = {}
        for k,_ in pairs(cache.axis_map) do
            mouse_delta[typ][k] = {0,0}
        end
    end
end

local function update_mouse_event()
    for mouse_event in mouse_left_mb:each() do
        local _,what,state,x,y = table.unpack(mouse_event)
        cache.cur_mouse_state = state
        if  ( state == "MOVE" or state == "DOWN" ) then
            if state == "MOVE" and cache.last_mouse_pos then
                local gizmo_type = cache.gizmo_type
                local picked_dir = cache.picked_dir
                if picked_dir then
                    local last_mouse_pos = cache.last_mouse_pos
                    local dx,dy = x-last_mouse_pos[1],(y-last_mouse_pos[2])*-1
                    -- 
                    local mouse_delta = cache.mouse_delta[gizmo_type][picked_dir]
                    mouse_delta[1] = mouse_delta[1] + dx
                    mouse_delta[2] = mouse_delta[2] + dy
                end
                -- count[1] = count[1] + (x-operate_gizmo_cache.last_mouse_pos[1])
                -- count[2] = count[2] + (y-operate_gizmo_cache.last_mouse_pos[2])
            else
                cache.mouse_pos = {x, y}
            end
            cache.last_mouse_pos = {x,y}
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

function editor_operate_gizmo_sys:data_changed()
    update_mouse_event()
    for _, target_entity_id in world:each "show_operate_gizmo" do
        local target_entity = world[target_entity_id]
        --sync transform gizmo
        local gizmo_eid =  cache.gizmo.eid
        local gizmo_entity = world[gizmo_eid]
        if target_entity then
            if cache.last_target_eid ~= target_entity_id then
                gizmo_entity.transform.parent = target_entity_id
            end
    
            scale_gizmo_to_normal(gizmo_eid)
    
            if target_entity_id ~= cache.last_target_eid then
                world:disable_tag(gizmo_eid,"hierarchy_visible")
                cache.last_target_eid = target_entity_id
            elseif not gizmo_entity.hierarchy_visible then
                world:enable_tag(gizmo_eid,"hierarchy_visible")
            end
        else
            if cache.last_target_eid then
                world:disable_tag(gizmo_eid,"hierarchy_visible")
                cache.last_target_eid = nil
            end
        end
    end
    --drag gizmo
    local mouse_delta = cache.mouse_delta
    for typ,dir_dic in pairs(mouse_delta) do
        for dir,v in pairs(dir_dic) do
            if v[1] ~=0 or v[2]~=0 then
                if typ == "position" then
                    gizmo_position_on_drag(cache,dir,v)
                elseif typ == "scale" then
                    gizmo_scale_on_drag(cache,dir,v)
                    cache.is_scale_draging = dir
                elseif typ == "rotation" then
                    gizmo_rotation_on_drag(cache,dir,v)
                    cache.is_rotation_draging = dir
                end
                v[1],v[2] = 0,0
            end
        end

    end
    if cache.cur_mouse_state == "UP" then
        if cache.is_scale_draging then
            gizmo_scale_on_release(cache)
            cache.is_scale_draging = nil
        elseif cache.is_rotation_draging then
            gizmo_rotation_on_release(cache)
            cache.is_rotation_draging = nil
        end
        cache.picked_dir = nil
    end
end

function editor_operate_gizmo_sys:after_pickup()
    local pickup = world:singleton "pickup"
    if pickup then
        local eid = pickup.pickup_cache.last_pick
        if eid and world[eid] and world[eid].gizmo_object then
            cache.picked_dir = world[eid].gizmo_object.dir
        end
    end
end
