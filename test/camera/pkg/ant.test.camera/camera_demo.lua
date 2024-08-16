local ecs = ...
local world = ecs.world
local w = world.w

local ImGui = require "imgui"
local bgfx = require "bgfx"
local icamera_ctrl = ecs.require "camera_ctrl"
local iviewport = ecs.require "ant.render|viewport.state"
local imaterial = ecs.require "ant.render|material"
local math3d = require "math3d"
local mathpkg = import_package "ant.math"
local mu, mc = mathpkg.util, mathpkg.constant
local XZ_PLANE <const> = math3d.constant("v4", {0, 1, 0, 0})

local m = ecs.system "main_system"

local gameobject = require "gameobject"

local function object(x, y, r)
	local proxy = { x = x or 0, y = y or 0, r = r or 0 }
	
	local eid
	
	local function on_ready(e)
		proxy.eid = eid
		gameobject.new(proxy)
		imaterial.set_property(e, "u_basecolor_factor", math3d.vector( 1,1,0,1 ))
	end
	
	eid = world:create_entity {
		policy = {
			"ant.render|render",
		},
		data = {
			scene       = { t = { 0,1,0} },
			material 	= "/pkg/ant.resources/materials/primitive.material",
			visible_masks = "main_view|cast_shadow",
			visible     = true,
			cast_shadow = true,
			mesh        = "cube.primitive",
			on_ready = on_ready,
		}
	}

	return proxy
end

local obj

function m:init_world()
	bgfx.maxfps(60)
    world:create_instance {
        prefab = "/asset/light.prefab"
    }
	world:create_entity {
		policy = {
			"ant.render|render",
		},
		data = {
			scene 		= {
				s = {10, 1, 10},
            },
			material 	= "/pkg/ant.resources/materials/mesh_shadow.material",
			visible     = true,
			mesh        = "plane.primitive",
		}
	}

	world:create_entity {
		policy = {
			"ant.render|render",
		},
		data = {
			scene       = { t = { 0,1,0} },
			material 	= "/pkg/ant.resources/materials/primitive.material",
			visible_masks = "main_view|cast_shadow",
			visible     = true,
			cast_shadow = true,
			mesh        = "cube.primitive",
			on_ready = function (e)
				imaterial.set_property(e, "u_basecolor_factor", math3d.vector( 1,0,0,1 ))
			end
		}
	}
	
	obj = object(0,0,0)

	icamera_ctrl.distance = 5
end

local function move_object()
	local r = obj.r + 1
	obj.r = r
	obj.x = 3 * math.sin(math.rad(r))
	obj.y = 3 * math.cos(math.rad(r))
end

local kb_mb             = world:sub {"keyboard"}
local key_press = {}

local mouse_mb          = world:sub {"mouse"}
local mouse_lastx, mouse_lasty

local GuiValue = {
	{ name = "distance_speed", 0.5 , min = 0.01, max = 2 },
	{ name = "pan_speed", 0.2, min = 0.01, max = 1 },
	{ name = "rot_speed",  2, min = 0.5, max = 5 },
	{ name = "pitch",  20, 80, min = -90, max = 90 },
	{ name = "x", -5, 5, min = -10, max = 10 },
	{ name = "z", -5, 5, min = -10, max = 10 },
}

do
	for _, item in ipairs(GuiValue) do
		if #item == 1 then
			GuiValue[item.name] = item[1]
		else
			local name = item.name
			item.label = name .. " range"
			icamera_ctrl.min[name] = item[1]
			icamera_ctrl.max[name] = item[2]
		end
	end
end

local function screen_to_world(x, y)
    x, y = iviewport.scale_xy(x, y)
    local vpmat = icamera_ctrl.vpmat
	local vr = icamera_ctrl.view_rect
	
    local ndcpt = mu.pt2D_to_NDC({x, y}, vr)
    ndcpt[3] = 0
    local p0 = mu.ndc_to_world(vpmat, ndcpt)
    ndcpt[3] = 1
    local p1 = mu.ndc_to_world(vpmat, ndcpt)
    local _ , p = math3d.plane_ray(p0, math3d.sub(p0, p1), XZ_PLANE, true)
    return p
end

function m:frame_update()
    for _, key, press, status in kb_mb:unpack() do
		key_press[key] = press == 1 or press == 2
	end
	
	local rot_speed = GuiValue.rot_speed
	
	if key_press.Q then
		icamera_ctrl.delta.yaw = rot_speed
	elseif key_press.E then
		icamera_ctrl.delta.yaw = -rot_speed
	end
	
	local pan_speed = GuiValue.pan_speed
	
	if key_press.W then
		icamera_ctrl.delta.z = pan_speed
	elseif key_press.S then
		icamera_ctrl.delta.z = -pan_speed
	end

	if key_press.A then
		icamera_ctrl.delta.x = -pan_speed
	elseif key_press.D then
		icamera_ctrl.delta.x = pan_speed
	end

	if key_press.Y then
		icamera_ctrl.delta.pitch = -rot_speed
	elseif key_press.H then
		icamera_ctrl.delta.pitch = rot_speed
	end
	
	for _, btn, state, x, y in mouse_mb:unpack() do
		if btn == "WHEEL" then
			icamera_ctrl.delta.distance = - state * GuiValue.distance_speed
		elseif btn == "RIGHT" then
			if state == "DOWN" then
				mouse_lastx, mouse_lasty = x, y
			elseif state == "MOVE" then
				local delta_x = x - mouse_lastx
				local delta_y = y - mouse_lasty
				icamera_ctrl.delta.yaw = delta_x * rot_speed / 4
				icamera_ctrl.delta.pitch = delta_y * rot_speed / 4
				mouse_lastx, mouse_lasty = x, y
			else
				mouse_lastx, mouse_lasty = nil, nil
			end
		elseif btn == "LEFT" then
			if state == "DOWN" then
				mouse_lastx, mouse_lasty = x, y
				
			elseif state == "MOVE" then
				local p0 = screen_to_world(mouse_lastx, mouse_lasty)
				local p1 = screen_to_world(x,y)
				if p0 and p1 then
					local delta = math3d.tovalue(math3d.sub(p0, p1))
					icamera_ctrl.x = icamera_ctrl.x + delta[1]
					icamera_ctrl.z = icamera_ctrl.z + delta[3]
				end
				if p1 then
					mouse_lastx, mouse_lasty = x, y
				end
			else
				mouse_lastx, mouse_lasty = nil, nil
			end
		end
    end
end

function m:data_changed()
	if not key_press.Space then
		move_object()
	end
	gameobject.flush(w)
	if ImGui.Begin("Camera", nil, ImGui.WindowFlags "AlwaysAutoResize|NoMove|NoTitleBar" ) then
		ImGui.LabelText ("Press space to pause",  "(%f,%f) R = %f", obj.x, obj.y, obj.r)
		ImGui.LabelText ("pan",  "Press W A S D or Left button")
		ImGui.LabelText ("yaw",  "Press Q E or Right button")
		ImGui.LabelText ("pitch",  "Press Y H or Right button")
		ImGui.LabelText ("distance", "Use mouse wheel")
		for _, item in ipairs(GuiValue) do
			local n = #item
			if n == 1 then
				if ImGui.SliderFloat(item.name, item, item.min, item.max) then
					GuiValue[item.name] = item[1]
				end
			elseif n == 2 then
				if ImGui.SliderFloat2(item.label, item, item.min, item.max) then
					icamera_ctrl.min[item.name] = item[1]
					icamera_ctrl.max[item.name] = item[2]
				end
			end
		end
		ImGui.End()
	end
end
