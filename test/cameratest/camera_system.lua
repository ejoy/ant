local ecs = ...
local world = ecs.world
local bgfx = require "bgfx"

--{@	must be the first system to call
local add_camera_entity_system = ecs.system "add_camera_entity"
function add_camera_entity_system:init()
	print("add_camera_entity_system:init()")
	world:new_entity("view_transform", "frustum")
end
--@}

--{@
local camera_init_system = ecs.system "camera_init_system"

camera_init_system.singleton "math3d"

function camera_init_system:init()
	print("camera_init_system:init()")
	for eid in world:each("view_transform") do
		local entity = world[eid]
		if entity and 
			entity.frustum and
			entity.view_transform then

			local vt = entity.view_transform
			vt.eye = self.math3d({0, 0, 0, 1}, "M")
			vt.direction = self.math3d({0, 0, 1, 0}, "M")

			local frustum = entity.frustum
			frustum.projMatMat = self.math3d({type = "projMat", fov = 90, aspect = 1024/768, n = 0.1, f = 10000}, "M")
		end
	end
end
--@}

--{@
local camera_system = ecs.system "camera_system"
camera_system.singleton "math3d"

function camera_system:init()
end

function camera_system:update()
	for eid in world:each "view_transform" do
		local e = world[eid]
		local frustum = e.frustum
		if frustum ~= nil then
			local ct = assert(e.view_transform)
			local viewMat = stack(ct.eye, ct.direction, "lm")
			print("viewMat type : " .. type(viewMat))
			local projMat = stack(frustum.projMat, "Dm")
			print("projMat type : " .. type(projMat))

			bgfx.set_view_transform(0, view, projMat)
		end
	end	
end
--@}