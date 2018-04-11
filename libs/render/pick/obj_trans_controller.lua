local ecs = ...
local world = ecs.world

local asset = require "asset"
local au = require "asset.util"
local ru = require "render.util"


ecs.component "pos_transform" {}
ecs.component "scale_transform" {}
ecs.component "rotator_transform" {}

ecs.component "object_transform" {
    translate_speed = 0.05,
    scale_speed = 0.005,
    rotation_speed = 0.5,
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

local function create_entity(ms, renderfile, name, color)
    local eid = world:new_entity("position", "scale", "rotation", "render", "name", "can_select")
    local obj = world[eid]
    obj.name.n = name

    ms(obj.position.v, {0, 0, 0, 1}, "=")
    ms(obj.rotation.v, {0, 0, 0}, "=")
    ms(obj.scale.v, {1, 1, 1}, "=")

    obj.render.info = asset.load(renderfile)
    
    obj.render.uniforms = {
        ["obj_trans/obj_trans.material"] = {
            u_color = ru.create_uniform("u_color", "v4", nil, function(u) u.value = ms(color, "m") end)
        }
    }

    obj.render.visible = false
    return eid
end

local function add_transform_entities(ms, basename, renderfile)
    local arg = {        
        {
            name = basename .. "-x",
            srt = {r={0, 90, 0}},
            color = {1, 0, 0, 1},
        },
        {
            name = basename .. "-y",
            srt = {r={-90, 0, 0}},
            color = {0, 1, 0, 1},
        },
        {
            name = basename .. "-z",
            srt = {r={0, 0, 0}},
            color = {0, 0, 1, 1},
        }
    }

    local controller = {}
    for _, v in ipairs(arg) do
        table.insert(controller, {eid = create_entity(ms, renderfile, v.name, v.color), srt=v.srt})
    end

    return controller
end

local function add_translate_entities(ms)
    return add_transform_entities(ms, "translate", "obj_trans/obj_trans.render")
end

local function add_scale_entities(ms)
    local scalerenderfile = "mem://scale_tranform_entities.render"
    au.write_to_file(scalerenderfile, 
    [[
        root = {
            {
                mesh = "cylinder.mesh",
                binding = {
                    material = "obj_trans/obj_trans.material", 
                },
                srt = {s={0.001, 0.001, 0.01}, t={0, 0, 0.5}},
            },
            {
                mesh = "cube.mesh",
                binding = {
                    material = "obj_trans/obj_trans.material", 
                },
                srt = {s={0.002}, t={0, 0, 1.1}}
            }
        }
    ]])
    
    return add_transform_entities(ms, "scale", scalerenderfile)
end

local function add_rotator_entities(ms)
    local renderfile = "mem://rotator_transform_entities.render"
    
    au.write_to_file(renderfile,
    [[
        mesh = "rotator.mesh"
        binding = {
            material = "obj_trans/obj_trans.material", 
        }
        srt = {s={0.01},r={0, 0, 90}}
    ]])    

    local controller = add_transform_entities(ms, "rotation", renderfile)
    controller[1].srt.r = {0, 0, 90}
    controller[2].srt.r = {0, 0, 0}
    controller[3].srt.r = {-90, 0, 0}

    local axisrenderfile = "mem://rotator_transform_axis_entity.render"
    au.write_to_file(axisrenderfile, [[
        root = {
            {
                mesh = "cylinder.mesh",
                binding = {
                    material = "obj_trans/obj_trans.material",
                },
                srt = {s={0.001, 0.001, 0.01}, r={0, 90, 0}, t={0.5, 0, 0}},
            },
            {
                mesh = "cylinder.mesh",
                binding = {
                    material = "obj_trans/obj_trans.material",
                },
                srt = {s={0.001, 0.001, 0.01}, r={0, -90, 0}, t={0, 0.5, 0}},
            },
            {
                mesh = "cylinder.mesh",
                binding = {
                    material = "obj_trans/obj_trans.material",
                },
                srt = {s={0.001, 0.001, 0.01}, t={0, 0, 0.5}},
            }
        }
    ]])
    -- local axis_eid = create_entity(ms, axisrenderfile, "rotationaxis", nil)
    -- local axis = assert(world[axis_eid])
    -- local uniforms = axis.render.uniforms
    -- for k, v in pairs(uniforms) do

    -- end


    -- table.insert(controller, axis_eid)


    return controller
end

function obj_trans_sys:init()
    local ot = self.object_transform    
    local ms = self.math_stack
    ot.controllers = {
        pos_transform = add_translate_entities(ms),        
        scale_transform = add_scale_entities(ms),
        rotator_transform = add_rotator_entities(ms),
    }
    
    ot.selected_mode = "pos_transform"
    ot.selected_eid = nil
    ot.sceneobj_eid = nil
end

local function update_controller_transform(ms, controller, obj_eid, follow_objrotation)
    local obj = assert(world[obj_eid])
    local objsrt = nil
    if follow_objrotation then
        objsrt = ms({type="srt", r=obj.rotation.v}, "P")
    end

    for _, v in ipairs(controller) do
        local eid = v.eid
        local e = assert(world[eid])
        local srt = v.srt

        local s, r = srt.s, srt.r
        if objsrt then
            s, r = ms(  {type="srt", s=s, r=r, t=srt.t}, 
                        objsrt, "*~PP")
        end

        ms(assert(e.position).v, assert(obj.position).v, "=")

        if r then
            ms(assert(e.rotation).v, r, "=")
        end

        if s then
            ms(assert(e.scale).v, s, "=")
        end
    end
end

local function update_contorller(ot, ms)
    local st_eid = ot.selected_eid
    if is_controller_id(ot.controllers, st_eid) then
        return 
    end

    local obj_eid = ot.sceneobj_eid    
    local mode = ot.selected_mode 

    local function show_controller(controller, show)
        for _, elem in ipairs(controller) do
            local e = assert(world[elem.eid])
            e.render.visible = show
        end
    end

    for m, controller in pairs(ot.controllers) do
        local bshow = obj_eid and obj_eid == st_eid and mode == m
        if bshow then
            update_controller_transform(ms, controller, obj_eid, mode ~= "rotator_transform")
        end
        show_controller(controller, bshow)
    end
end

function obj_trans_sys:update()
    local ot = self.object_transform
    if not ot.select_changed then
        return 
    end

    ot.select_changed = false

    update_contorller(ot, self.math_stack)
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

                update_contorller(ot, ms)
            else
                local upC = string.upper(c)                
                if upC == "CT" then   -- shift + T
                    ot.selected_mode = "pos_transform"
                elseif upC == "CR" then   -- shift + R
                    ot.selected_mode = "rotator_transform"
                elseif upC == "CS" then   -- shift + S
                    ot.selected_mode = "scale_transform"
                elseif upC == "CP" then                
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
        local controller = ot.controllers[mode]
        if controller == nil then
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

        local zdir = ms(sceneobj.rotation.v, "dnP")
        local xdir = ms({0, 1, 0, 0}, zdir, "xnP")
        local ydir = ms(zdir, xdir, "xnP")

        if mode == "pos_transform" then            
            if selected_axis then
                local pos = sceneobj.position.v

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

                for _, elem in ipairs(controller) do
                    local e = assert(world[elem.eid])
                    ms(e.position.v, pos, "=")
                end                
            end
        elseif mode == "scale_transform" then
            if selected_axis then                
                local scale = ms(sceneobj.scale.v, "T")

                local function scale_by_axis(dir, idx)
                    local speed = ot.scale_speed
                    local v = select_step_value(dir) > 0 and speed or -speed
                    scale[idx] = scale[idx] + v
                    ms(sceneobj.scale.v, scale, "=")
                end

                if axis_name == "x" then
                    scale_by_axis(xdir, 1)
                elseif axis_name == "y" then
                    scale_by_axis(ydir, 2)
                elseif axis_name == "z" then
                    scale_by_axis(zdir, 3)
                else
                    error("scale entity axis not found, axis_name : " .. axis_name)
                end
            end
        elseif mode == "rotator_transform" then
            if selected_axis then
                dprint("in rotator")
                local rotation = ms(sceneobj.rotation.v, "T")

                local function rotate(dir, idx)
                    local speed = ot.rotation_speed
                    local v = select_step_value(dir) > 0 and speed or -speed
                    rotation[idx] = rotation[idx] + v
                    ms(sceneobj.rotation.v, rotation, "=")

                    dprint("rotation : ", sceneobj.rotation.v)
                end

                if axis_name == "x" then
                    rotate(xdir, 1)
                elseif axis_name == "y" then
                    rotate(ydir, 2)
                elseif axis_name == "z" then
                    rotate(zdir, 3)
                else
                    error("rotation entity axis not found, axis_name : " .. axis_name)
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
