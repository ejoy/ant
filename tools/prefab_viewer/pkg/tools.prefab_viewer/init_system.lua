local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d = require "math3d"
local iom = ecs.require "ant.objcontroller|obj_motion"
local irmlui = ecs.require "ant.rmlui|rmlui_system"
local S = ecs.system "init_system"
local font = import_package "ant.font"

function S.init()
end

function S.init_world()
    world:create_instance {
		prefab = "/pkg/tools.prefab_viewer/assets/prefabs/light.prefab",
	}
	-- ground plane
	-- world:create_entity {
	-- 	policy = {
	-- 		"ant.render|render",
	-- 	},
	-- 	data = {
	-- 		scene = {s = {200, 1, 200}},
	-- 		mesh  = "/pkg/tools.prefab_viewer/assets/glb/plane.glb|meshes/Plane_P1.meshbin",
	-- 		material    = "/pkg/tools.prefab_viewer/assets/materials/texture_plane.material",
	-- 		render_layer = "background",
	-- 		visible_state= "main_view",
	-- 		on_ready = function (e)
	-- 			imaterial.set_property(e, "u_uvmotion", math3d.vector{0, 0, 100, 100})
	-- 		end
	-- 	},
	-- }

	-- terrain
	
	-- test prefab
	world:create_instance {
		prefab = "/pkg/tools.prefab_viewer/assets/prefabs/preview.prefab"
	}
    -- local miner = world:create_instance("/pkg/tools.prefab_viewer/assets/prefabs/miner-1.prefab")
    -- miner.on_ready = function(instance)
    --     for _, eid in ipairs(instance.tag["*"]) do
    --         local e <close> = world:entity(eid, "tag?in anim_ctrl?in")
    --         if e.anim_ctrl then
    --             iani.load_events(eid, "/pkg/tools.prefab_viewer/assets/prefabs/miner-1.event")
    --         end
    --     end
    --     iani.play(instance, {name = "work", loop = true, speed = 1.0, manual = false})
    -- end

    -- camera
    local mq = w:first "main_queue camera_ref:in"
    local ce<close> = world:entity(mq.camera_ref, "camera:in")
    local eyepos = math3d.vector(0, 60, -60)
    iom.set_position(ce, eyepos)
    local dir = math3d.normalize(math3d.sub(math3d.vector(0.0, 0.0, 0.0, 1.0), eyepos))
    iom.set_direction(ce, dir)

    -- rmlui
    font.import "/pkg/ant.resources.binary/font/Alibaba-PuHuiTi-Regular.ttf"
    local window = irmlui.open "/pkg/tools.prefab_viewer/assets/ui/joystick.html"
	window.addEventListener("message", function(data) world:pub {"joystick", data} end)
end

local last_mousex
local last_mousey
local mousex
local mousey
local rotate_mode
local move_mode
local camera_speed = 1.0
local move_speed = 2.5
local zoom_speed = 1.0
local rotate_speed = 0.002

local joystick_dir = {0, 0, math3d.ref()}
local joystick_active = false
local function on_joystick()
	if not joystick_active then
		return
	end
	local mq = w:first("main_queue camera_ref:in render_target:in")
	local ce<close> = world:entity(mq.camera_ref, "scene:update")
	local pos = iom.get_position(ce)
	local mat = math3d.matrix{s = iom.get_scale(ce), r = iom.get_rotation(ce), t = pos}
	local xdir = math3d.normalize(math3d.index(mat, 1))
	-- local zdir = math3d.normalize(math3d.index(mat, 3))
	local zdir = math3d.cross(xdir, math3d.vector(0, 1, 0))
	local dir = math3d.normalize(math3d.add(math3d.mul(xdir, joystick_dir[1]), math3d.mul(zdir, joystick_dir[2])))
	
	-- local dir = math3d.transform(math3d.mul(joystick_dir[3], iom.get_rotation(ce)), math3d.vector(0, 0, 1), 0)
	-- dir = math3d.transform(math3d.inverse(math3d.matrix{r = iom.get_rotation(ce)}), dir, 0)
	iom.set_position(ce, math3d.add(pos, math3d.mul(dir, 0.8)))
end

local function on_key(key, press)
	local pressed = (press == 1 or press == 2)
	local pan = false
	if key == "A" or key == "D" or key == "W" or key == "S" or key == "F" then
		pan = true
	end
	if not pressed or not pan then
		return
	end
	local mq = w:first("main_queue camera_ref:in render_target:in")
	local ce<close> = world:entity(mq.camera_ref, "scene:update")
	local pos = iom.get_position(ce)
	local dt = move_speed * camera_speed
	local mat = math3d.matrix{s = iom.get_scale(ce), r = iom.get_rotation(ce), t = pos}
	local xdir = math3d.normalize(math3d.index(mat, 1))
	local zdir = math3d.normalize(math3d.index(mat, 3))
	local newpos
	if key == "A" then
		newpos = math3d.add(pos, math3d.mul(math3d.normalize(xdir), -dt))
	elseif key == "D" then
		newpos = math3d.add(pos, math3d.mul(math3d.normalize(xdir), dt))
	elseif key == "W" then
		newpos = math3d.add(pos, math3d.mul(math3d.normalize(zdir), dt))
	elseif key == "S" then
		newpos = math3d.add(pos, math3d.mul(math3d.normalize(zdir), -dt))
	end
	if newpos then
		iom.set_position(ce, newpos)
	end
end

local function on_right_mouse(dx, dy)
	local mq = w:first("main_queue camera_ref:in render_target:in")
	local ce<close> = world:entity(mq.camera_ref, "scene:update")
	local delta_yaw = dx * rotate_speed-- * camera_speed
	local delta_pitch = dy * rotate_speed
	local rad = math3d.tovalue(math3d.quat2euler(iom.get_rotation(ce)))
	local yaw = rad[2] - delta_yaw
	local pitch = rad[1] - delta_pitch
	-- min/max pitch
	if pitch > 1.47 then
		pitch = 1.47
	elseif pitch < -1.47 then
		pitch = -1.47
	end
	local rot = math3d.quaternion{pitch, yaw, 0}
	iom.set_rotation(ce, rot)
end

local function on_middle_mouse(dx, dy)
	local mq = w:first("main_queue camera_ref:in render_target:in")
	local ce<close> = world:entity(mq.camera_ref, "scene:update")
	local pos = iom.get_position(ce)
	local mat = math3d.matrix{s = iom.get_scale(ce), r = iom.get_rotation(ce), t = pos}
	local xdir = math3d.normalize(math3d.index(mat, 1))
	local ydir = math3d.normalize(math3d.index(mat, 2))
	local dir = math3d.add(math3d.mul(xdir, dx), math3d.mul(ydir, -dy))
	iom.set_position(ce, math3d.add(pos, math3d.mul(dir, 0.02 * move_speed * camera_speed)))
end

local function on_wheel(delta)
	local mq = w:first("main_queue camera_ref:in render_target:in")
	local ce<close> = world:entity(mq.camera_ref, "scene:update")
	local dt = delta * zoom_speed * move_speed * camera_speed
	local pos = iom.get_position(ce)
	local zdir = math3d.index(math3d.matrix{s = iom.get_scale(ce), r = iom.get_rotation(ce), t = pos}, 3)
	iom.set_position(ce, math3d.add(pos, math3d.mul(math3d.normalize(zdir), dt)))
end

local kb_mb         = world:sub {"keyboard"}
local mouse_mb      = world:sub {"mouse"}
local gesture_pinch = world:sub { "gesture", "pinch"}
local gesture_pan   = world:sub {"gesture", "pan"}
local joystick_mb = world:sub {"joystick"}
function S:data_changed()
    for _, key, press, state in kb_mb:unpack() do
        on_key(key, press)
    end

    for _, what, e in gesture_pinch:unpack() do
		on_wheel(e.velocity)
	end
	if not rotate_mode then
		for _, e in joystick_mb:unpack() do
			joystick_active = e.moving
			if e.moving then
				local angle = math.atan(-e.dy, e.dx)
				joystick_dir[1] = math.cos(angle)
				joystick_dir[2] = math.sin(angle)
				joystick_dir[3].q = math3d.quaternion{0, math.atan(e.dx, -e.dy), 0}
			end
		end
		on_joystick()
	end
	for _, _, e in gesture_pan:unpack() do
		if not joystick_active then
			if e.state == "began" then
				rotate_mode = true
			elseif e.state == "ended" then
				rotate_mode = false
			elseif e.state == "changed" then
				on_right_mouse(-e.dx, -e.dy)
			end
		end
	end
    for _, btn, state, x, y in mouse_mb:unpack() do
		if state == "DOWN" then
			last_mousex, last_mousey = x, y
			if btn == "MIDDLE" then
				move_mode = true
            -- elseif btn == "RIGHT" then
            --     rotate_mode = true
			end
		end
		if state == "MOVE" then
			if move_mode then
				mousex, mousey = x, y
				on_middle_mouse(last_mousex - mousex, last_mousey - mousey)
				last_mousex, last_mousey = x, y
            -- elseif rotate_mode then
            --     mousex, mousey = x, y
            --     on_right_mouse(last_mousex - mousex, last_mousey - mousey)
            --     last_mousex, last_mousey = x, y
			end
		end
		if state == "UP" then
			-- rotate_mode = false
			move_mode = false
		end
	end
end

function S:camera_usage()

end
