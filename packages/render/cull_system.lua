local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"
local mc = import_package "ant.math".constant
local setting = import_package "ant.settings".setting
local disable_cull = setting:data().graphic.disable_cull

local cullcore = ecs.clibs "cull.core"

local cull_ids = setmetatable({}, {__index = function (t, k)
	local id = w:component_id(k .. "_cull")
	t[k] = id
	return id
end})


local cull_sys = ecs.system "cull_system"
local function build_cull_args()
	w:clear "cull_args"
	
	for qe in w:select "visible queue_name:in camera_ref:in cull_args:new" do
		local ce <close> = w:entity(qe.camera_ref, "camera:in")
		local vpmat = ce.camera.viewprojmat
		qe.cull_args = {
			viewprojmat		= vpmat,
			frustum_planes 	= math3d.frustum_planes(vpmat),
			cull_id			= cull_ids[qe.queue_name],
		}
	end
end

function cull_sys:cull()
	if disable_cull then
		return
	end

	build_cull_args()
	cullcore.cull()
end
