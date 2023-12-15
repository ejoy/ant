local ecs	= ...
local world	= ecs.world
local w		= world.w

local math3d				= require "math3d"
local queuemgr				= ecs.require "queue_mgr"
local setting				= import_package "ant.settings"
local disable_cull<const>	= setting:get "graphic/disable_cull"

local cullcore = world:clibs "cull.core"

local CULL_ARGS = setmetatable({}, {__index = function (t, k)
	local v = {
		queue_index		= queuemgr.queue_index(k),
		frustum_planes	= nil,
	}
	t[k] = v
	return v
end})


local cull_sys = ecs.system "cull_system"

cull_sys.init = cullcore.init
cull_sys.exit = cullcore.exit

local function build_cull_args()
	w:clear "cull_args"
	for qe in w:select "visible queue_name:in camera_ref:in cull_args:new" do
		local ce <close> = world:entity(qe.camera_ref, "camera:in")
		local ca = CULL_ARGS[qe.queue_name]
		ca.frustum_planes = math3d.frustum_planes(ce.camera.viewprojmat)
		qe.cull_args = ca
	end
end

function cull_sys:cull()
	if disable_cull then
		return
	end

	if w:check "camera_changed" then
		build_cull_args()
		cullcore.cull()
	end
end
