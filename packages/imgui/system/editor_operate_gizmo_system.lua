local ecs = ...
local world = ecs.world
local mathpkg   = import_package "ant.math"
local ms        = mathpkg.stack
local renderpkg = import_package "ant.render"
local camerautil= renderpkg.camera

local util = require "system.editor_system_util"
local WatcherEvent = require "hub_event"

local show_operate_gizmo = ecs.tag "show_operate_gizmo"
local gizmo_object = ecs.component "gizmo_object"
    ["opt"].type "string"   --"position"/"rotation"/"scale"
    ["opt"].dir "string"    --"x"/"y"/"z"  *"xy"/"yz"/"xz"

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

local function scale_gizmo_to_normal(gizmo)
    local mq = world:singleton_entity "main_queue"
    local camera = world[mq.camera_eid].camera
    local _, _, vp = ms:view_proj(camera, camera.frustum, true)
    local et = gizmo.transform
    if et.world then
        local _,_,t = ms(et.world,"~TTT")
        local tvp  = ms(vp,t,"*T")
        local scale = math.abs(tvp[4]/7)
        local parent_e = world[et.parent]
        if parent_e then
            local parent_trans = world[et.parent].transform.world
            local ps,_,_ = ms(parent_trans,"~TTT")
            local ps_lua = ms(ps,"T")
            world:add_component_child(et,"s","vector",
                {scale/ps_lua[1],scale/ps_lua[2],scale/ps_lua[3],0})
        else
            log.error("target entity not found,parent eid:",et.parent)
        end
    end
end

local function pos_to_screen(pos,trans,viewproj,w,h)
    local scale = ms(trans.s,"T")
    local vec4 = { pos[1]/scale[1],pos[2]/scale[2],pos[3]/scale[3],1}
    -- log.info_a(vec4)
    local trans_world = trans.world
    local proj_pos = ms(viewproj,trans_world,vec4,"**T")
    local x = proj_pos[1]/proj_pos[4]
    local y = proj_pos[2]/proj_pos[4]
    -- log.info_a("proj_pos",proj_pos[1]/proj_pos[4],proj_pos[2]/proj_pos[4])
    -- local screen_pos = (x+1)/2*w,(y+1)/2*h
    return {(x+1)/2*w,(y+1)/2*h}
end

local function convert_to_model_axis(trans,axis_unit)
    local r = trans.r
    return  ms(axis_unit,r,"qS*T")
end

local function update_world(trans)
    local srt = ms:srtmat(trans)
    local base = trans.base
    local worldmat = trans.world
    if base then
        srt = ms(trans.base, srt, "*P") 
    end

    local peid = trans.parent
    if peid then
        local parent = world[peid]
        local pt = parent.transform
        ms(worldmat, pt.world, srt, "*=")
    else
        ms(worldmat, srt, "=")
    end
    return worldmat
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
        local _, _, viewproj = ms:view_proj(camera, camera.frustum, true)
        local trans = target_entity.transform
        local r_axis_unit = convert_to_model_axis(trans,axis_unit)
        -- log.info_a("axis_unit:",r_axis_unit)
        local cur_pos = ms(trans.t,"T")
        local viewport = mq.render_target.viewport
        -- log.info_a("viewport",viewport.rect)
        local w,h = viewport.rect.w,viewport.rect.h
        local screen_pos0 = pos_to_screen({0,0,0},trans,viewproj,w,h)
        local screen_pos1= pos_to_screen(axis_unit,trans,viewproj,w,h)
        local sceen_unit = {screen_pos1[1]-screen_pos0[1],screen_pos1[2]-screen_pos0[2],0}
        -- log.info_a("sceen_unit:",sceen_unit)
        local normalize_sceen_unit =  ms(sceen_unit,"nT")
        local sceen_unit_dis = nil
        if normalize_sceen_unit[1]~=0 then
            sceen_unit_dis = sceen_unit[1]/normalize_sceen_unit[1]
        else
            sceen_unit_dis = sceen_unit[2]/normalize_sceen_unit[2]
        end
        local effect_dis = dx*normalize_sceen_unit[1]+dy*normalize_sceen_unit[2]
        local t = effect_dis/sceen_unit_dis
        local new_pos = {cur_pos[1]+r_axis_unit[1]*t,cur_pos[2]+r_axis_unit[2]*t,cur_pos[3]+r_axis_unit[3]*t}
        -- local move_count = cache.move_count
        -- move_count[1] = move_count[1] + r_axis_unit[1]*t
        -- move_count[2] = move_count[2] + r_axis_unit[2]*t
        -- move_count[3] = move_count[3] + r_axis_unit[3]*t
        -- log.info_a("new_pos",new_pos)
        -- ms(trans.t,new_pos,"=")
        world:add_component_child(trans,"t","vector",new_pos)
        -- update_world(trans)
    end
end

local function add_gizmo_scale_length(scale_object,picked_dir,add_length)
    local scale_box_id = scale_object["box_"..picked_dir]
    local scale_box = world[scale_box_id]
    local scale_line_id = scale_object["line_"..picked_dir]
    local scale_line= world[scale_line_id]
    local pos = ms(scale_box.transform.t,add_length,"+T")
    -- log.info_a("add_gizmo_scale_length",add_length,pos)
    world:add_component_child(scale_box.transform,"t","vector",pos)
    local line_length = scale_object.line_length
    world:add_component_child(scale_line.transform,"s","vector",
        {pos[1]/line_length,pos[2]/line_length,pos[3]/line_length})
    return pos
end

local function gizmo_scale_on_release(cache)
    local picked_dir = cache.is_scale_draging
    assert(picked_dir)
    local scale_object = cache.gizmo.scale
    local line_length = scale_object.line_length
    local scale_box_id = scale_object["box_"..picked_dir]
    local axis_unit = cache.axis_map[picked_dir]
    local scale_box = world[scale_box_id]
    local pos = {axis_unit[1]*line_length,axis_unit[2]*line_length,axis_unit[3]*line_length}
    -- log.info_a("scale_box.transform.t",pos)
    world:add_component_child(scale_box.transform,"t","vector",pos)
    local scale_line_id = scale_object["line_"..picked_dir]
    local scale_line= world[scale_line_id]
    world:add_component_child(scale_line.transform,"s","vector",axis_unit)
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
        local _, _, viewproj = ms:view_proj(camera, camera.frustum, true)
        local viewport = mq.render_target.viewport
        local w,h = viewport.rect.w,viewport.rect.h
        local screen_pos0 = pos_to_screen({0,0,0},scale_box_trans,viewproj,w,h)
        local screen_pos1= pos_to_screen(axis_unit,scale_box_trans,viewproj,w,h)
        local sceen_unit = {screen_pos1[1]-screen_pos0[1],screen_pos1[2]-screen_pos0[2],0}
        local normalize_sceen_unit =  ms(sceen_unit,"nT")
        local sceen_unit_dis = nil
        if normalize_sceen_unit[1]~=0 then
            sceen_unit_dis = sceen_unit[1]/normalize_sceen_unit[1]
        else
            sceen_unit_dis = sceen_unit[2]/normalize_sceen_unit[2]
        end
        local effect_dis = dx*normalize_sceen_unit[1]+dy*normalize_sceen_unit[2]
        local t = effect_dis/sceen_unit_dis
        local tvec3 = {axis_unit[1]*t,axis_unit[2]*t,axis_unit[3]*t}
        add_gizmo_scale_length(scale_object,picked_dir,tvec3)
        local line_length = scale_object.line_length
        local scale_add = {tvec3[1]/line_length,tvec3[2]/line_length,tvec3[3]/line_length}
        local trans = target_entity.transform
        local old_scale = ms(trans.s,"T")
        local new_scale = {}
        for i = 1,3 do
            new_scale[i] = old_scale[i]*(scale_add[i] + 1)
        end
        world:add_component_child(trans,"s","vector",new_scale)
        -- world:update_func("event_changed")()
        -- local gizmo_eid =  cache.gizmo.eid
        -- local gizmo_entity = world[gizmo_eid]
        -- scale_gizmo_to_normal(gizmo_entity)
        -- world:update_func("event_changed")()

    end
end

local function gizmo_rotation_on_drag(cache,picked_type,mouse_delta)
    --旋转轴被自己的矩阵变化了
    local function world_to_model(point,model_srt)
        local t = point[4]
        point[4] = 1
        local mp = ms(point,model_srt,"iS*T")
        point[4] = t
        return mp
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
            
            local _,_,viewproj = ms:view_proj(camera,camera.frustum,true)
            r_axis_unit = convert_to_model_axis(trans,axis_unit)
            rotat_unit_quat = ms({type="quat",axis=r_axis_unit,radian={0.02}},"T")

            ------------------------
            local inject_pos_world
            do 
                local gizmo_eid = cache.gizmo.eid
                local gizmo_trans = world[gizmo_eid].transform
                local gizmo_world = gizmo_trans.world
                local _,_,point_world = ms(gizmo_world,"~TTT")
                local axis_unit_p = {axis_unit[1],axis_unit[2],axis_unit[3],1}
                local normal_world = ms(point_world,gizmo_trans.world,axis_unit_p,"*-nT")
                assert(cache.mouse_pos)
                local click_pos = util.mouse_project_onto_plane(world,cache.mouse_pos,point_world,normal_world)
                inject_pos_world = ms( point_world,click_pos,point_world,"-n+T" )
            end
            ------------------------
            local click_in_model = world_to_model(inject_pos_world,trans.world)
            local click_in_model_roted = ms(click_in_model,rot_unit,"qS*T")
            local viewport = mq.render_target.viewport
            local w,h = viewport.rect.w,viewport.rect.h
            local screen_pos0 = pos_to_screen(click_in_model,trans,viewproj,w,h)
            local screen_pos1= pos_to_screen(click_in_model_roted,trans,viewproj,w,h)
            local screen_unit = {screen_pos1[1]-screen_pos0[1],screen_pos1[2]-screen_pos0[2],0}
            normalize_sceen_unit =  ms(screen_unit,"nT")
            -- log.info_a("inject_pos_world",inject_pos_world,
            --     "click_in_model:",click_in_model,
            --     "click_in_model_roted",click_in_model_roted,
            --     "w,h",w,h,
            --     "screen_pos0",screen_pos0,
            --     "screen_pos1",screen_pos1,
            --     "screen_unit",screen_unit,
            --     "normalize_sceen_unit",normalize_sceen_unit
            --     )
            if normalize_sceen_unit[1]~=0 then
                sceen_unit_dis = screen_unit[1]/normalize_sceen_unit[1]
            else
                sceen_unit_dis = screen_unit[2]/normalize_sceen_unit[2]
            end
            cache.last_rotation = {
                normalize_sceen_unit = normalize_sceen_unit,
                sceen_unit_dis = sceen_unit_dis,
                r_axis_unit = r_axis_unit,
            }


            -- local viewport = mq.render_target.viewport
            -- local w,h = viewport.rect.w,viewport.rect.h
            -- local screen_pos0 = pos_to_screen({0,0,0},trans,viewproj,w,h)
            -- local screen_pos1= pos_to_screen(axis_unit,trans,viewproj,w,h)
            -- local screen_unit = {screen_pos1[1]-screen_pos0[1],screen_pos1[2]-screen_pos0[2],0}
            ----------------------
            -- local eyepos = camera.eyepos
            -- local eyepos_in_model = ms(eyepos,trans.world,"i*nT")
            -- local eyepos_in_model_roted = ms(eyepos_in_model,rot_unit,"qS*T")
            -- local viewport = mq.render_target.viewport
            -- local w,h = viewport.rect.w,viewport.rect.h
            -- local screen_pos0 = pos_to_screen(eyepos_in_model,trans,viewproj,w,h)
            -- local screen_pos1= pos_to_screen(eyepos_in_model_roted,trans,viewproj,w,h)
            -- local screen_unit = {screen_pos1[1]-screen_pos0[1],screen_pos1[2]-screen_pos0[2],0}
            -- normalize_sceen_unit =  ms(screen_unit,"nT")
            -- if normalize_sceen_unit[1]~=0 then
            --     sceen_unit_dis = screen_unit[1]/normalize_sceen_unit[1]
            -- else
            --     sceen_unit_dis = screen_unit[2]/normalize_sceen_unit[2]
            -- end
            -- cache.last_rotation = {
            --     normalize_sceen_unit = normalize_sceen_unit,
            --     sceen_unit_dis = sceen_unit_dis,
            --     r_axis_unit = r_axis_unit,
            -- }
        end
        local effect_dis = dx*normalize_sceen_unit[1]+dy*normalize_sceen_unit[2]
        local t = effect_dis/sceen_unit_dis
        local rotat_t_quat = ms({type="quat",axis=r_axis_unit,radian={0.01*t}},"T")
        local cur_rot = ms(trans.r,"qT")
        local new_rot = ms(rotat_t_quat,cur_rot,"*eT")
        -- local new_rot =  {cur_rot[1]+rotat_e[1]*t,cur_rot[2]+rotat_e[2]*t,cur_rot[3]+rotat_e[3]*t}
        world:add_component_child(trans,"r","vector",new_rot)
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
        world:add_component(gizmo[old_typ].eid,"hierarchy_visible",false)
        world:add_component(gizmo[typ].eid,"hierarchy_visible",true)
        operate_gizmo_cache.gizmo_type = typ
    end

end

local gizmo_sys =  ecs.system "editor_operate_gizmo_system"
gizmo_sys.require_singleton "operate_gizmo_cache"
function gizmo_sys:init()
    --create gizmo
    local operate_gizmo_cache = world:singleton "operate_gizmo_cache"
    assert(not operate_gizmo_cache.gizmo_eid)
    local gizmo = util.create_gizmo(world)
    for i,typ in ipairs(GizmoType) do
        local eid = gizmo[typ].eid
        world:add_component(eid,"hierarchy_visible",typ ==operate_gizmo_cache.gizmo_type)
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
    hub.subscribe(WatcherEvent.GizmoType,on_gizmo_type_change,self)
    --------------
    self.message.observers:add({
        mouse = function (_, x, y, what, state)
            if what == "LEFT" then
                -- local count = operate_gizmo_cache.count
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
    })

end


function gizmo_sys:update()
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
        -- local trans = target_entity.transform
        -- assert(trans and trans.world,"trans and trans.world is nil,trans is "..tostring(trans))
        -- local s,r,t = ms(trans.world,"~TTT")
        
        -- world: gizmo_entity
        -- world:add_component_child(gizmo_entity.transform,"t","vector",t)
        -- world:add_component_child(gizmo_entity.transform,"r","vector",r)
        scale_gizmo_to_normal(gizmo_entity)

        if target_entity_id ~= operate_gizmo_cache.last_target_eid then
            world:add_component(gizmo_eid,"hierarchy_visible",false)
            operate_gizmo_cache.last_target_eid = target_entity_id
        elseif not gizmo_entity.hierarchy_visible then
            world:add_component(gizmo_eid,"hierarchy_visible",true)
        end
    else
        if operate_gizmo_cache.last_target_eid then
            world:add_component(gizmo_eid,"hierarchy_visible",false)
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

function gizmo_sys:pickup()
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

