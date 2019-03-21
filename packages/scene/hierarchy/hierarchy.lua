local ecs = ...

local hiemodule = require "hierarchy"
local math3d_adapter = require "math3d.adapter"
local ms = import_package "ant.math".stack

ecs.component_alias("hierarchy", "resource")
ecs.component_alias("hierarchy_name_mapper", "entityid{}")

local bind_math_sys = ecs.system "hierarchy_bind_math"
bind_math_sys.dependby "math_adapter"
function bind_math_sys:bind_math_adapter()
	local node_mt = hiemodule.node_metatable()	
	node_mt.add_child = math3d_adapter.vector(ms, node_mt.add_child, 3)
	node_mt.transform = math3d_adapter.vector(ms, node_mt.transform, 2)
end