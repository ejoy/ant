local ecs = ...
local world = ecs.world

local asset = require "asset"
local mu = require "math.util"
local cu = require "common.util"
local components_util = require "render.components.util"


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
obj_trans_sys.singleton "constant"
obj_trans_sys.singleton "control_state"
obj_trans_sys.singleton "message_component"

obj_trans_sys.depend "constant_init_sys"


local function is_controller_id(controllers, eid)
	if controllers then
		for _, controller in pairs(controllers) do
			if controller:is_controller_id(eid) then
				return true
			end
		end
	end
	return false
end

local function play_object_transform(ms, ot, dx, dy)
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
        local dirX, dirY = dirInVS[1], dirInVS[2]            
        return (dirX > dirY) and dx or dy
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

			controller:update_transform(ot.sceneobj_eid)            
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
            local rotation = ms(sceneobj.rotation.v, "T")

            local function rotate(dir, idx)
                local speed = ot.rotation_speed
                local v = select_step_value(dir) > 0 and speed or -speed
                rotation[idx] = rotation[idx] + v
                ms(sceneobj.rotation.v, rotation, "=")
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


local function print_select_object_transform(ms, eid)
    local obj = assert(world[eid])
    dprint("select object name : ", obj.name.n)
    mu.print_srt(ms, obj)
end

local function update_contorller(ot, ms)
    local st_eid = ot.selected_eid
    if is_controller_id(ot.controllers, st_eid) then
        return 
    end

    local obj_eid = ot.sceneobj_eid    
	local mode = ot.selected_mode 
	
    for m, controller in pairs(ot.controllers) do
        local bshow = obj_eid and obj_eid == st_eid and mode == m
		if bshow then
			controller:update_transform(obj_eid)            
		end

		controller:show(bshow)
    end
end

local function register_message(msg_comp, ot, ms)
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
                        print_select_object_transform(ms, ot.selected_eid)
                    end
                end
            
            end
        end

    end
    local lastX, lastY
    function message:motion(x, y, status)
        local leftBtnDown = status.LEFT
        if not leftBtnDown then
            return 
        end

        if lastX == nil or lastY == nil then
            lastX, lastY = x, y
            return 
        end

        local deltaX, deltaY = x - lastX, (lastY - y)  -- y value is from up to down, need flip
        lastX, lastY = x, y

        play_object_transform(ms, ot, deltaX, deltaY)
    end

    local observers = msg_comp.msg_observers
    observers:add(message)
end

local function add_axis_entites(ms, prefixname, suffixname, headmeshfile, axismeshfile, materialfile, tag_comp, color)
	local hie_eid = components_util.create_hierarchy_entity(ms, world, 
						"hierarchy-" .. prefixname .. "-" .. suffixname)
	world:add_component(hie_eid, tag_comp)
	local hie_entity = world[hie_eid]

	local hie = hie_entity.editable_hierarchy.root
	hie[1] = {
		name = "head",
		transform = {
			s={0.002}, 
			t={0, 0, 1.1},
		}
	}
	hie[2] = {
		name = "axis",
		transform = {
			s={0.001, 0.001, 0.01}, 
			t={0, 0, 0.5},
		}
	}

	local namemapper = hie_entity.hierarchy_name_mapper.v

	local fullaxis_config = {
		head = {
			name = "head-",
			meshfile = headmeshfile,
		},
		axis = {
			name = "axis-",
			meshfile = axismeshfile,
		}
	}

	for k, v in pairs(fullaxis_config) do
		local eid = components_util.create_render_entity(ms, world, prefixname .. v.name .. suffixname,		
							v.meshfile, materialfile)
		world:add_component(eid, "hierarchy_parent", tag_comp, "editor")
		local obj = world[eid]
		obj.hierarchy_parent.eid = hie_eid

		local properties = assert(obj.material.content[1].properties)
		properties.u_color = {type="color", name="color", value=cu.deep_copy(color)}
		obj.can_render.visible = false
		namemapper[k] = eid
	end
	return hie_eid
end

local function add_axis_base_transform_entites(ms, basename, headmeshfile, axismeshfile, tag_comp, colors)
	local xaxis_eid = add_axis_entites(ms, basename, "x", 
										headmeshfile, axismeshfile,
										"obj_trans/obj_trans.material", tag_comp, colors["red"])
	
	local yaxis_eid = add_axis_entites(ms, basename, "y", 
										headmeshfile, axismeshfile,
										"obj_trans/obj_trans.material", tag_comp, colors["green"])

	--ms(yaxis.rotation.v, {-90, 0, 0}, "=")	

	local zaxis_eid = add_axis_entites(ms, basename, "z", 
										headmeshfile, axismeshfile,
										"obj_trans/obj_trans.material", tag_comp, colors["blue"])

	local rootaxis_eid = components_util.create_hierarchy_entity(ms, world, basename)
	world:add_component(rootaxis_eid, tag_comp)
	local axis_root = world[rootaxis_eid]

	local eh = axis_root.editable_hierarchy.root
	eh[1] = {name = "xaxis", 
		transform = {
			--r = ms({0, 90, 0}, "qT")
			r = {0, math.cos(math.pi * 0.25), 0, math.sin(math.pi * 0.25)}
		}
	}
	eh[2] = {name = "yaxis", 
		transform = {
			r = {math.cos(-math.pi * 0.25), 0, 0, math.sin(-math.pi * 0.25)}
		}
	}
	eh[3] = {name = "zaxis", }
	
	local namemapper = axis_root.hierarchy_name_mapper.v
	namemapper.xaxis = xaxis_eid
	namemapper.yaxis = yaxis_eid
	namemapper.zaxis = zaxis_eid
	
	local controllers = {		
		root = rootaxis_eid,
	}

	function controllers:update_transform(objeid)
		local obj = world[objeid]

		local root_eid = self.root
		local root = world[root_eid]
		
		ms(root.rotation.v, obj.rotation.v, "=")
		ms(root.position.v, obj.position.v, "=")

		world:change_component(root_eid, "rebuild_hierarchy")
		world:notify()
	end

	function controllers:iter_axis()
		local root_eid = self.root
		local root = world[root_eid]
		local namemapper = root.hierarchy_name_mapper.v
		return next, namemapper, nil
	end

	local function iter_axiselem(entity)
		local namemapper = entity.hierarchy_name_mapper.v
		return next, namemapper, nil
	end

	function controllers:print()
		local root_eid = self.root
		local root = world[root_eid]
		print("root name : ", root.name.n)

		mu.print_srt(root, 1)
		for axis_name, axis_eid in pairs(root.hierarchy_name_mapper.v) do
			print("\n\taxis name : ", axis_name, ", axis eid : ", axis_eid)
			local axis = world[axis_eid]
			mu.print_srt(axis, 2)
			for elemname, elemeid in pairs(axis.hierarchy_name_mapper.v) do
				print("\n\t\taxis elem name : ", elemname, "axis eid : ", elemeid)
				mu.print_srt(axis, 3)
			end
		end
	end

	function controllers:show(visible)
		for _, axis_eid in self:iter_axis() do
			local axisentity = world[axis_eid]
			for _, eid in iter_axiselem(axisentity) do
				local e = world[eid]
				e.can_render.visible = visible
			end
		end
	end

	function controllers:is_controller_id(check_eid)
		for _, axis_eid in self:iter_axis() do
			local axisentity = world[axis_eid]
			for _, eid in iter_axiselem(axisentity) do
				if eid == check_eid then
					return true
				end
			end
		end

		return false
	end

	world:change_component(rootaxis_eid, "rebuild_hierarchy")
	world:notify()
	return controllers
end

local function add_translate_entities(ms, colors)
	return add_axis_base_transform_entites(ms, "translate", "cone.mesh", "cylinder.mesh", "pos_transform", colors)
end

local function add_scale_entities(ms, colors)
	return add_axis_base_transform_entites(ms, "scale", "cube.mesh", "cylinder.mesh", "scale_transform", colors)	
end

local function add_rotator_entities(ms, colors)
	local elems = {
		x = {
			name = "rotate-x",
			rotation = {-90, 0, 0},
			axis_name = "rotate-axis-x",
			axis_srt = {s={0.001, 0.001, 0.01}, r={0, 90, 0}, t={2.5, 0, 0}},
			color_name = "red",
		},
		y = {
			name = "rotate-y",
			rotation = {0, 0, 90},
			axis_name = "rotate-axis-y",
			axis_srt = {s={0.001, 0.001, 0.01}, r={-90, 0, 0}, t={0, 2.5, 0}},
			color_name = "green",
		},
		z = {
			name = "rotate-z",
			rotation = {-90, 90, 0},
			axis_name = "rotate-axis-z",
			axis_srt = {s={0.001, 0.001, 0.01}, r={0, 0, 0}, t={0, 0, 2.5}},
			color_name = "blue",
		},
	}

	local controllers = {}
	for k, elem in pairs(elems) do
		local eid = components_util.create_render_entity(ms, world, elem.name, "rotator.mesh",
													"obj_trans/obj_trans.material")
		world:add_component(eid, "rotator_transform")
		local entity = world[eid]
		ms(entity.scale.v, {0.01, 0.01, 0.01}, "=")
		ms(entity.rotation.v, elem.rotation, "=")
		local properties = assert(entity.material.content[1].properties)
		properties.u_color = {type="color", name="color", value=cu.deep_copy(colors[elem.color_name])}

		entity.can_render.visible = false

		local ids = {}
		table.insert(ids, eid)

		local axis_eid = components_util.create_render_entity(ms, world, elem.axis_name, "cylinder.mesh",
																"obj_trans/obj_trans.material")
		world:add_component(axis_eid, "rotator_transform")
		world:remove_component(axis_eid, "can_select")											

		local axis_entity = world[axis_eid]		
		local axis_srt = elem.axis_srt
		ms(	axis_entity.scale.v, axis_srt.s, "=",
			axis_entity.rotation.v, axis_srt.r, "=",
			axis_entity.position.v, axis_srt.t, "=")
		local axis_properties = assert(axis_entity.material.content[1].properties)
		axis_properties.u_color = {type="color", name="color", value=cu.deep_copy(colors[elem.color_name])}

		axis_entity.can_render.visible = false

		table.insert(ids, axis_eid)

		controllers[k] = ids
	end

	function controllers:update_transform(objeid)
		local obj = world[objeid]
		local objsrt = mu.srt_from_entity(ms, obj)

		for _, n in ipairs {"x", "y", "z"} do
			local axis_ids = self[n]			
			for _, ctrleid in ipairs(axis_ids) do
				local ctrl = world[ctrleid]
				local srt = mu.srt_from_entity(ms, ctrl)
				local s, r, t = ms(srt, objsrt, "*~PPP")
				ms(ctrl.position.v, t, "=")
				ms(ctrl.rotation.v, r, "=")
					
			end
		end
	end

	function controllers:show(visible)
		for _, n in ipairs {"x", "y", "z"} do
			local axis_ids = self[n]
			for _, eid in ipairs(axis_ids) do
				local e = world[eid]
				e.can_render.visible = visible
			end
		end
	end

	function controllers:is_controller_id(check_eid)
		for _, n in ipairs {"x", "y", "z"} do
			local axis_ids = self[n]
			for _, eid in ipairs(axis_ids) do
				if eid == check_eid then
					return true
				end
			end
		end
		return false
	end

	return controllers
end

function obj_trans_sys:init()
    local ot = self.object_transform    
    local ms = self.math_stack
    local cc = assert(self.constant.tcolors)
    ot.controllers = {
        pos_transform = add_translate_entities(ms, cc),        
        scale_transform = add_scale_entities(ms, cc),
        rotator_transform = add_rotator_entities(ms, cc),
    }
    
    ot.selected_mode = "pos_transform"
    ot.selected_eid = nil
    ot.sceneobj_eid = nil

    register_message(self.message_component, ot, ms)
end

-- function obj_trans_sys:update()
--     local ot = self.object_transform
--     if not ot.select_changed then
--         return 
--     end

--     ot.select_changed = false

--     update_contorller(ot, self.math_stack)
-- end

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

    local select_changed = ot.selected_eid ~= last_eid

    if select_changed then
        dprint("select change, scene obj eid : ", ot.sceneobj_eid, ", selected eid : ", ot.selected_eid)
    end

    return select_changed
end

function obj_trans_sys.notify:pickup(set)
    local ot = self.object_transform
    if update_select_state(ot) then
        update_contorller(ot, self.math_stack)
    end

    self.control_state.state = is_controller_id(ot.controllers, ot.selected_eid) and "object" or "default"
end
