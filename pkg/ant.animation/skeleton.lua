local math3d_adapter = import_package "ant.math.adapter"
local skemodule = require "hierarchy".skeleton

local bd_mt = skemodule.builddata_metatable()
bd_mt.joint = math3d_adapter.getter(bd_mt.joint, "m", 3)
