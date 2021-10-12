local ecs 	= ...
local world = ecs.world
local w 	= world.w

local assetmgr = require "asset"

local ms_sys = ecs.system "meshskin_system"
function ms_sys:component_init()
	w:clear "meshskin_result"
	for e in w:select "INIT meshskin:in meshskin_result:new" do
		e.meshskin_result = assetmgr.resource(e.meshskin)
	end
end
