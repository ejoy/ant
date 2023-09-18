local ecs = ...
local ig		= ecs.require "ant.group|group"

local vg_sys = ecs.system "viewgroup_system"
function vg_sys:init()
	ig.enable_from_name("DEFAULT", "view_visible", true)
end