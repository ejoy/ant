local ecs = ...
local world = ecs.world
local mathpkg   = import_package "ant.math"
local mu = mathpkg.util
local ms = mathpkg.stack
local util = require "system.editor_system_util"

local show_operate_gizmo = ecs.tag "show_operate_gizmo"
local gizmo_object = ecs.tag "gizmo_object"

local operate_gizmo_cache = ecs.singleton "operate_gizmo_cache"
function operate_gizmo_cache:init()
    local self = {}
    self.gizmo_eid = nil
    self.last_target_eid = nil
    self.key_map = nil
    self.picked_type = nil -- "x"/"y","z", not supported yet:("xy","xz","yz")
    self.last_mouse_pos = nil
    self.mouse_delta = nil
    -- self.count = {0,0}
    -- self.move_count = {0,0,0}
    return self
end

-- local function gizmo_pick_and_move(gizmo_cache,picked_type,mouse_x,mouse_y,state)
--     if state == "DOWN" then
--         gizmo_cache.last_mouse = {mouse_x,mouse_y}
--     elseif state == "MOVE" then
--         --todo
--     end
-- end

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

local function gizmo_on_drag(cache,picked_type,mouse_delta)
    local target_entity_id = world:first_entity_id("show_operate_gizmo")
    local target_entity = target_entity_id and world[target_entity_id]
    --assert(target_entity)
    if target_entity then
        local typ = picked_type --"x","y","z"
        local axis_unit = cache.axis_map[typ] -- {1,0,0} or {0,1,0} or {0,0,1}
        local dx,dy = mouse_delta[1],mouse_delta[2]
        log("dxdy",dx,dy)
        --calc part1
        local maincamera = world:first_entity("main_queue")
        local camera = maincamera.camera
        -- log.info_a("maincamera",maincamera)
        local _, _, viewproj = ms:view_proj(camera, camera.frustum, true)
        local trans = target_entity.transform
        r_axis_unit = convert_to_model_axis(trans,axis_unit)
        log.info_a("axis_unit:",r_axis_unit)
        local cur_pos = ms(trans.t,"T")
        local viewport = maincamera.render_target.viewport
        -- log.info_a("viewport",viewport.rect)
        local w,h = viewport.rect.w,viewport.rect.h
        local screen_pos0 = pos_to_screen({0,0,0},trans,viewproj,w,h)
        local screen_pos1= pos_to_screen(axis_unit,trans,viewproj,w,h)
        local sceen_unit = {screen_pos1[1]-screen_pos0[1],screen_pos1[2]-screen_pos0[2],0}
        log.info_a("sceen_unit:",sceen_unit)
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
        update_world(trans)

    end

end



local gizmo_sys =  ecs.system "editor_operate_gizmo_system"
gizmo_sys.singleton "operate_gizmo_cache"
gizmo_sys.singleton "message"
function gizmo_sys:init()
    --create gizmo
    local operate_gizmo_cache = self.operate_gizmo_cache
    assert(not operate_gizmo_cache.gizmo_eid)
    operate_gizmo_cache.gizmo = util.create_position_gizmo(world)
    operate_gizmo_cache.key_map = {
        line_x = "x",
        cone_x = "x",
        line_y = "y",
        cone_y = "y",
        line_z = "z",
        cone_z = "z",
    }
    operate_gizmo_cache.axis_map = {
        x = {1,0,0},
        y = {0,1,0},
        z = {0,0,1},
    }
    operate_gizmo_cache.mouse_delta = {}
    local mouse_delta = operate_gizmo_cache.mouse_delta
    for k,_ in pairs(operate_gizmo_cache.axis_map) do
        mouse_delta[k] = {0,0}
    end
    --------------
    self.message.observers:add({
        mouse = function (_, x, y, what, state)
            if what == "LEFT" then
                -- local count = operate_gizmo_cache.count

                if  ( state == "MOVE" or state == "DOWN" ) then
                    if state == "MOVE" and operate_gizmo_cache.last_mouse_pos then
                        local picked_type = operate_gizmo_cache.picked_type
                        if operate_gizmo_cache.picked_type then
                            local last_mouse_pos = operate_gizmo_cache.last_mouse_pos
                            local dx,dy = x-last_mouse_pos[1],(y-last_mouse_pos[2])*-1
                            -- 
                            local mouse_delta = operate_gizmo_cache.mouse_delta[picked_type]
                            mouse_delta[1] = mouse_delta[1] + dx
                            mouse_delta[2] = mouse_delta[2] + dy
                        end
                        -- count[1] = count[1] + (x-operate_gizmo_cache.last_mouse_pos[1])
                        -- count[2] = count[2] + (y-operate_gizmo_cache.last_mouse_pos[2])
                    else
                        
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

local function scale_gizmo_to_normal(gizmo)
    local maincamera = world:first_entity("main_queue")
    local camera = maincamera.camera
    local _, _, vp = ms:view_proj(camera, camera.frustum, true)
    local et = gizmo.transform
    local _,_,t = ms(et.world,"~TTT")
    local tvp  = ms(vp,t,"*T")
    local scale = math.abs(tvp[4]/7)
    world:add_component_child(et,"s","vector",{scale,scale,scale,0})
end

function gizmo_sys:update()
    local target_entity_id = world:first_entity_id("show_operate_gizmo")
    local target_entity = target_entity_id and world[target_entity_id]
    --sync transform gizmo
    local gizmo_eid =  self.operate_gizmo_cache.gizmo.eid
    local gizmo_entity = world[gizmo_eid]
    if target_entity then
        
        local trans = target_entity.transform
        assert(trans and trans.world,"trans and trans.world is nil,trans is "..tostring(trans))
        local s,r,t = ms(trans.world,"~TTT")
        
        -- world: gizmo_entity
        world:add_component_child(gizmo_entity.transform,"t","vector",t)
        world:add_component_child(gizmo_entity.transform,"r","vector",r)
        scale_gizmo_to_normal(gizmo_entity)

        if target_entity_id ~= self.operate_gizmo_cache.last_target_eid then
            world:add_component(gizmo_eid,"hierarchy_visible",false)
            self.operate_gizmo_cache.last_target_eid = target_entity_id
        elseif not gizmo_entity.hierarchy_visible then
            world:add_component(gizmo_eid,"hierarchy_visible",true)
        end
    else
        if self.operate_gizmo_cache.last_target_eid then
            world:add_component(gizmo_eid,"hierarchy_visible",false)
            self.operate_gizmo_cache.last_target_eid = nil
        end
    end
    --drag gizmo
    local mouse_delta = self.operate_gizmo_cache.mouse_delta
    for t,v in pairs(mouse_delta) do
        if v[1] ~=0 or v[2]~=0 then
            gizmo_on_drag(self.operate_gizmo_cache,t,v)
            v[1],v[2] = 0,0
        end
    end
end

function gizmo_sys:pickup()
    local pickup_entity = world:first_entity "pickup"
    if pickup_entity then
        local picked_type = nil
        local pickup_comp = pickup_entity.pickup
        local eid = pickup_comp.pickup_cache.last_pick
        if eid and world[eid] and world[eid].gizmo_object then
            local key_map = self.operate_gizmo_cache.key_map
            local gizmo = self.operate_gizmo_cache.gizmo
            for k,v in pairs(key_map) do
                if eid == gizmo[k] then
                    picked_type = v
                    break
                end
            end
        end
        self.operate_gizmo_cache.picked_type = picked_type
    end
end

