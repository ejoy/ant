local ecs	= ...
local world	= ecs.world
local w		= world.w

local math3d				= require "math3d"
local setting				= import_package "ant.settings".setting
local disable_cull<const>	= setting:data().graphic.disable_cull

local cullcore = ecs.clibs "cull.core"

local CULL_ARGS = setmetatable({}, {__index = function (t, k)
	local v = {
		cull_id			= w:component_id(k .. "_cull"),
		renderable_id	= w:component_id(k .. "_renderable"),
		frustum_planes	= nil,
	}
	t[k] = v
	return v
end})


local cull_sys = ecs.system "cull_system"
local function build_cull_args()
	w:clear "cull_args"
	
	for qe in w:select "visible queue_name:in camera_ref:in cull_args:new" do
		local ce <close> = w:entity(qe.camera_ref, "camera:in")
		local ca = CULL_ARGS[qe.queue_name]
		ca.frustum_planes = math3d.frustum_planes(ce.camera.viewprojmat)
		qe.cull_args = ca
	end
end

function cull_sys:cull()
	if disable_cull then
		return
	end

	build_cull_args()
	cullcore.cull()
end
