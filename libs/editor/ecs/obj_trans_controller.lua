local ecs = ...
local world = ecs.world

local assetmgr = require "asset"
local mu = require "math.util"
local cu = require "common.util"
local components_util = require "render.components.util"

local hierarchy_module = require "hierarchy"

local axisbase_controller_hierarchyname = "hierarchy/axisbase_contrller.hierarchy"
local axis_hierarchyname = "hierarchy/axis.hierarchy"
local rotator_hierarchyname = "hierarchy/rotator.hierarchy"

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

local function get_controller_position(controller)
	local root_eid = assert(controller.root)
	return world[root_eid].position.v
end

local function update_transform(controller, objeid)	
	controller:update_transform(world[objeid])

	world:change_component(controller.root, "rebuild_hierarchy")
	world:notify()
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
	
	local ctrlpos = get_controller_position(controller)

    local sceneobj = assert(world[ot.sceneobj_eid])
    local selected_axis = assert(world[ot.selected_eid])
    local name = selected_axis.name.n
    local axis_name = name:match(".+-([xyz])$")

    local function select_step_value(dir)
        local camera = world:first_entity("main_camera")
        local view, proj = mu.view_proj_matrix(ms, camera)

		local originInWS = ctrlpos
		local posInWS = ms(originInWS, dir, "+P")

		local results = {}

		for _, p in ipairs{originInWS, posInWS} do
			local posInCS = ms(p, view, proj, "**T")
			local clipcoord = posInCS[4]
			local posInNDC = {posInCS[1]/clipcoord, posInCS[2]/clipcoord}
			local posInSNS = {(posInNDC[1] + 1) * 0.5, (posInNDC[2] + 1) * 0.5}	-- screen normalize space
			local vr = camera.view_rect
			local screen = {posInSNS[1] * vr.w, vr.h * (1 - posInSNS[2])}
			table.insert(results, screen)
		end

		local point1 = results[1]
		local point2 = results[2]

		local dirInScreen = {point2[1] - point1[1], point2[2] - point1[2]}
		local len = math.sqrt(dirInScreen[1] * dirInScreen[1] + dirInScreen[2] * dirInScreen[2])
		dirInScreen[1], dirInScreen[2] = dirInScreen[1] / len, dirInScreen[2] / len
		return dirInScreen[1] * dx + dirInScreen[2] * dy        
    end

	local xdir, ydir, zdir = ms(sceneobj.rotation.v, "bPPP")

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

			update_transform(controller, ot.sceneobj_eid)
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
			update_transform(controller, obj_eid)
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

        local deltaX, deltaY = x - lastX, y - lastY  -- y value is from up to down, need flip
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

	hie_entity.editable_hierarchy.ref_path = axis_hierarchyname
	hie_entity.editable_hierarchy.root = assetmgr.load(axis_hierarchyname, {editable=true})

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

local function iter_axis(root_eid)	
	local root = world[root_eid]
	local namemapper = root.hierarchy_name_mapper.v
	return next, namemapper, nil
end

local function iter_axiselem(entity)
	local namemapper = entity.hierarchy_name_mapper.v
	return next, namemapper, nil
end

local function add_axis_base_transform_entites(ms, basename, headmeshfile, axismeshfile, tag_comp, colors)
	local rootaxis_eid = components_util.create_hierarchy_entity(ms, world, basename)
	world:add_component(rootaxis_eid, tag_comp)

	local axis_root = world[rootaxis_eid]
	local namemapper = axis_root.hierarchy_name_mapper.v
	namemapper.xaxis = add_axis_entites(ms, basename, "x", 
										headmeshfile, axismeshfile,
										"obj_trans/obj_trans.material", tag_comp, colors["red"])
	
	namemapper.yaxis = add_axis_entites(ms, basename, "y", 
										headmeshfile, axismeshfile,
										"obj_trans/obj_trans.material", tag_comp, colors["green"])

	namemapper.zaxis = add_axis_entites(ms, basename, "z", 
										headmeshfile, axismeshfile,
										"obj_trans/obj_trans.material", tag_comp, colors["blue"])

	axis_root.editable_hierarchy.ref_path = axisbase_controller_hierarchyname
	axis_root.editable_hierarchy.root = assetmgr.load(axisbase_controller_hierarchyname, {editable = true})
	
	local controllers = {		
		root = rootaxis_eid,
	}

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
		for _, axis_eid in iter_axis(self.root) do
			local axisentity = world[axis_eid]
			for _, eid in iter_axiselem(axisentity) do
				local e = world[eid]
				e.can_render.visible = visible
			end
		end
	end

	function controllers:update_transform(obj)		
		local root = world[self.root]
		ms(root.rotation.v, obj.rotation.v, "=")
		ms(root.position.v, obj.position.v, "=")
	end

	function controllers:is_controller_id(check_eid)
		for _, axis_eid in iter_axis(self.root) do
			local axisentity = world[axis_eid]
			for _, eid in iter_axiselem(axisentity) do
				if eid == check_eid then
					return true
				end
			end
		end

		return false
	end
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
		xaxis = {suffixname = "x", clrname="red"},
		yaxis = {suffixname = "y", clrname="green"},
		zaxis = {suffixname = "z", clrname="blue"},
	}

	local root_eid = components_util.create_hierarchy_entity(ms, world, "rotator")
	world:add_component(root_eid, "rotator_transform")
	local hie_entity = world[root_eid]
	hie_entity.editable_hierarchy.ref_path = axisbase_controller_hierarchyname
	hie_entity.editable_hierarchy.root = assetmgr.load(axisbase_controller_hierarchyname, {editable=true})
	local namemapper = hie_entity.hierarchy_name_mapper.v

	local function add_elem_entity(elemname, clrname)
		local elem_eid = components_util.create_hierarchy_entity(ms, world, "rotator-elem-" .. elemname)
		world:add_component(elem_eid, "rotator_transform")
		local elem = world[elem_eid]

		elem.editable_hierarchy.root = assetmgr.load(rotator_hierarchyname, {editable=true})
		elem.editable_hierarchy.ref_path = rotator_hierarchyname

		local mapper = elem.hierarchy_name_mapper.v
		local function add_entity(name, meshfilename, colorname)
			local eid = components_util.create_render_entity(ms, world, name, meshfilename,
			"obj_trans/obj_trans.material")
			world:add_component(eid, "rotator_transform", "editor", "hierarchy_parent")
			local entity = world[eid]
	
			local properties = assert(entity.material.content[1].properties)
			properties.u_color = {type="color", name="color", value=cu.deep_copy(colors[colorname])}
			entity.can_render.visible = false
			mu.identify_transform(ms, entity)
	
			entity.hierarchy_parent.eid = elem_eid
			return eid
		end
	
		mapper["rotator"] = add_entity("rotator-" .. elemname, "rotator.mesh", clrname)
		local axiseid = add_entity("rotator-axis-" .. elemname, "cylinder.mesh", clrname)
		mapper["rotator-axis"] = axiseid
		world:remove_component(axiseid, "can_select")
		return elem_eid
	end

	for name, elem in pairs(elems) do
		namemapper[name] = add_elem_entity(elem.suffixname, elem.clrname)
	end

	local controllers = {
		root = root_eid
	}

	function controllers:show(visible)
		for _, axis_eid in iter_axis(self.root) do
			local axisentity = world[axis_eid]
			for _, eid in iter_axiselem(axisentity) do
				local e = world[eid]
				e.can_render.visible = visible
			end
		end		
	end

	function controllers:update_transform(obj)		
		local root = world[self.root]
		ms(root.position.v, obj.position.v, "=")		
	end

	function controllers:is_controller_id(check_eid)
		for _, axis_eid in iter_axis(self.root) do
			local axisentity = world[axis_eid]
			for _, eid in iter_axiselem(axisentity) do
				if eid == check_eid then
					return true
				end
			end
		end
		return false
	end
	return controllers
end

-- local function create_axisbase_hierarchy(ms)
-- 	local path = require "filesystem.path"
-- 	local ctl_root = hierarchy_module.new()
-- 	ctl_root[1] = {name = "xaxis", 
-- 		transform = {
-- 			r = {0, math.cos(math.pi * 0.25), 0, math.sin(math.pi * 0.25)}
-- 		}
-- 	}
-- 	ctl_root[2] = {name = "yaxis", 
-- 		transform = {
-- 			r = {math.cos(-math.pi * 0.25), 0, 0, math.sin(-math.pi * 0.25)}
-- 		}
-- 	}
-- 	ctl_root[3] = {name = "zaxis", }

-- 	hierarchy_module.save(ctl_root, path.join(assetmgr.assetdir(), axisbase_controller_hierarchyname))

-- 	local axis_root = hierarchy_module.new()	
-- 	axis_root[1] = {
-- 		name = "head",
-- 		transform = {
-- 			s={0.002}, 
-- 			t={0, 0, 1.1},
-- 		}
-- 	}
-- 	axis_root[2] = {
-- 		name = "axis",
-- 		transform = {
-- 			s={0.001, 0.001, 0.01}, 
-- 			t={0, 0, 0.5},
-- 		}
-- 	}
	
-- 	hierarchy_module.save(axis_root, path.join(assetmgr.assetdir(), axis_hierarchyname))

-- 	local rotator_root = hierarchy_module.new()
-- 	rotator_root[1] = {
-- 		name = "rotator",
-- 		transform = {
-- 			s={0.01, 0.01, 0.01}, r=ms({0, 0, 0}, "qT")
-- 		}
-- 	}

-- 	rotator_root[2] = {
-- 		name = "rotator-axis",
-- 		transform = {
-- 			s={0.001, 0.001, 0.01}, r=ms({0, 0, 0}, "qT"), t={0.5, 0, 0},
-- 		}
-- 	}
-- 	hierarchy_module.save(rotator_root, path.join(assetmgr.assetdir(), rotator_hierarchyname))
-- end

function obj_trans_sys:init()
	local ms = self.math_stack
	--create_axisbase_hierarchy(ms)

    local ot = self.object_transform    
    
    local cc = assert(self.constant.tcolors)
    ot.controllers = {
        pos_transform = add_translate_entities(ms, cc),        
        scale_transform = add_scale_entities(ms, cc),
        rotator_transform = add_rotator_entities(ms, cc),
	}

	for _, c in pairs(ot.controllers) do
		world:change_component(c.root, "rebuild_hierarchy")
	end

	world:notify()
    
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
