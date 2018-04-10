local ecs = ...
local world = ecs.world

local asset = require "asset"
local ru = require "render.util"

ecs.component "pos_transform" {}
ecs.component "scale_transform" {}
ecs.component "rotator_transform" {}

ecs.component "object_transform" {
    translate_speed = 0.05,
    scale_speed = 0.05,
    rotation_speed = 0.05,
}


local obj_trans_sys = ecs.system "obj_transform_system"
obj_trans_sys.singleton "object_transform"
obj_trans_sys.singleton "math_stack"

local function is_controller_id(controllers, p_eid)
    for _, controller in pairs(controllers) do
        for _, elem in ipairs(controller) do
            local eid = elem.eid
            if eid == p_eid then
                return true
            end
        end
    end

    return false
end


local function create_translate_entity(ms, name, color)
    local eid = world:new_entity("position", "scale", "rotation", "render", "name", "pos_transform", "can_select")
    local translate = world[eid]
    translate.name.n = name

    ms(translate.position.v, {0, 0, 0, 1}, "=")
    ms(translate.rotation.v, {0, 0, 0}, "=")
    ms(translate.scale.v, {1, 1, 1}, "=")

    translate.render.info = asset.load "obj_trans/obj_trans.render"
    
    translate.render.uniforms = {
        ["obj_trans/obj_trans.material"] = {
            u_color = ru.create_uniform("u_color", "v4", nil, function(u) u.value = ms(color, "m") end)
        }
    }

    translate.render.visible = false
    return eid
end

local function add_trans_entity(ms)
    local arg = {
        {
            name = "translate-x",
            srt = {r={0, 90, 0}},
            color = {1, 0, 0, 1},
        },
        {
            name = "translate-y",
            srt = {r={-90, 0, 0}},
            color = {0, 1, 0, 1},
        },
        {
            name = "translate-z",
            srt = {r={0, 0, 0}},
            color = {0, 0, 1, 1},
        }
    }

    local translate_elems = {}
    for _, v in ipairs(arg) do
        table.insert(translate_elems, {eid = create_translate_entity(ms, v.name, v.color), srt=v.srt})
    end

    return translate_elems
end

function obj_trans_sys:init()
    local ot = self.object_transform    
    ot.controllers = {
        pos_transform = add_trans_entity(self.math_stack),        
    }
    
    ot.selected_mode = "pos_transform"
    ot.selected_eid = nil
    ot.sceneobj_eid = nil
end

local function update_controller_transform(ms, controller, obj_eid)
    local obj = assert(world[obj_eid])
    local objsrt = ms({type="srt", r=obj.rotation.v}, "P")
    for _, v in ipairs(controller) do
        local eid = v.eid
        local e = assert(world[eid])
        local srt = v.srt
        local s, r = ms({type="srt", s=srt.s, r=srt.r, t=srt.t}, 
                        objsrt, "*~PP")

        ms(assert(e.position).v, assert(obj.position).v, "=")
        ms(assert(e.rotation).v, r, "=")
        ms(assert(e.scale).v, s, "=")
    end
end

function obj_trans_sys:update()
    local ot = self.object_transform

    if not ot.select_changed then
        return 
    end

    ot.select_changed = false

    local obj_eid = ot.sceneobj_eid
    local st_eid = ot.selected_eid

    local ms = self.math_stack

    if is_controller_id(ot.controllers, st_eid) then
        return 
    end

    local function show_controller(controller, show)
        for _, elem in ipairs(controller) do
            local e = assert(world[elem.eid])
            e.render.visible = show
        end
    end

    local function update_contorller(controller)
        update_controller_transform(ms, controller, obj_eid)
        show_controller(controller, true)
    end

    local mode = ot.selected_mode  

    for m, controller in pairs(ot.controllers) do
        if obj_eid and obj_eid == st_eid and mode == m then
            update_contorller(controller)
        else
            show_controller(controller, false)
        end
    end
end

-- controller system
local obj_controller_sys = ecs.system "obj_controller"
obj_controller_sys.singleton "message_component"
obj_controller_sys.singleton "object_transform"
obj_controller_sys.singleton "math_stack"
obj_controller_sys.singleton "control_state"

obj_controller_sys.depend "obj_transform_system"

local function print_select_object_transform(eid)
    local obj = assert(world[eid])
    dprint("select object name : ", obj.name.n)
    dprint("scale : ", obj.scale.v)
    dprint("position : ", obj.position.v)
    dprint("rotation : ", obj.rotation.v)
end

function obj_controller_sys:init()
    local ot = self.object_transform
    local ms = self.math_stack
    local states = self.message_component.states

    local message = {}

    function message:keypress(c, p)        
        if c == nil then return end

        if p then 
            if c == "SP" then
                local map = {
                    [""] = "pos_transform",
                    pos_transform = "scale_transform",
                    scale_transform = "rotator_transform",
                    rotator_transform = "pos_transform"   
                }

                local mode = ot.selected_mode 
                ot.selected_mode = map[mode]
            else
                
                local upC = string.upper(c)
                dprint("c : ", upC)
                if upC == "CT" then   -- shift + T
                    ot.selected_mode = "pos_transform"
                elseif upC == "CR" then   -- shift + R
                    ot.selected_mode = "rotator_transform"
                elseif upC == "CS" then   -- shift + S
                    ot.selected_mode = "scale_transform"
                elseif upC == "CP" then
                    dprint("in P")
                    if ot.selected_eid then
                        print_select_object_transform(ot.selected_eid)
                    end
                end
            
            end

            dprint("select mode : ", ot.selected_mode)
        end

    end
    local lastX, lastY
    function message:motion(x, y)
        local leftBtnDown = states.buttons["LEFT"]
        if not leftBtnDown then
            return 
        end

        if lastX == nil or lastY == nil then
            lastX, lastY = x, y
            return 
        end

        local deltaX, deltaY = x - lastX, (lastY - y)  -- y value is from up to down, need flip
        lastX, lastY = x, y

        if  ot.sceneobj_eid == nil or             
            ot.selected_eid == nil or
            ot.sceneobj_eid == ot.selected_eid then -- mean no axis selected
            return
        end

        local mode = ot.selected_mode
        local elems = ot.controllers[mode]
        if elems == nil then
            return 
        end

        local sceneobj = assert(world[ot.sceneobj_eid])
        local selected_axis = assert(world[ot.selected_eid])
        local name = selected_axis.name.n
        local axis_name = name:match(".+-([xyz])$")

        local function select_step_value(dir)
            local camera = world:first_entity("main_camera")
            local view_mat = ms(camera.position.v, camera.rotation.v, "dLP")                

            local dirInVS = ms(dir, view_mat, "*T")
            local dx, dy = dirInVS[1], dirInVS[2]            
            return (dx > dy) and deltaX or deltaY
        end

        if mode == "pos_transform" then            
            if selected_axis then
                local pos = sceneobj.position.v
                local zdir = ms(sceneobj.rotation.v, "dnP")
                local xdir = ms({0, 1, 0, 0}, zdir, "xnP")
                local ydir = ms(zdir, xdir, "xnP")
                local function move(dir)
                    local speed = ot.translate_speed
                    local v = select_step_value(dir) > 0 and speed or -speed
                    ms(pos, pos, dir, {v}, "*+=")
                end

                if axis_name == "x" then
                    move(xdir)
                elseif axis_name == "y" then
                    move(ydir)
                elseif axis_name == "z" then
                    move(zdir)
                else
                    error("move entity axis not found, axis_name : " .. axis_name)
                end

                local controller = assert(ot.controllers[mode])
                for _, elem in ipairs(controller) do
                    local e = assert(world[elem.eid])
                    ms(e.position.v, pos, "=")
                end                
            end
        end
    end

    local observers = self.message_component.msg_observers
    observers:add(message)
end

function obj_controller_sys:update()
    
end

local function update_select_state(ot)
    local mode = ot.selected_mode
    local pu_e = assert(world:first_entity("pickup"))
    local pickup_eid = assert(pu_e.pickup).last_eid_hit                
    local last_eid = ot.selected_eid
    if pickup_eid then
        if mode == "" or not is_controller_id(ot.controllers, pickup_eid) then
            ot.sceneobj_eid = pickup_eid                        
        end

        ot.selected_eid = pickup_eid
        
    else
        ot.sceneobj_eid = nil
        ot.selected_eid = nil                    
    end

    ot.select_changed = ot.selected_eid ~= last_eid

    if ot.select_changed then
        dprint("select change, scene obj eid : ", ot.sceneobj_eid, ", selected eid : ", ot.selected_eid)
    end
end

function obj_controller_sys.notify:pickup(set)
    local ot = self.object_transform
    update_select_state(ot)
    if is_controller_id(ot.controllers, ot.selected_eid) then
        self.control_state.state = "object"
    else
        self.control_state.state = "default"
    end

    dprint("state : ", self.control_state.state)

end
