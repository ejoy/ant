local mathadapter = import_package "ant.math.adapter"
local math3d_adapter = require "math3d.adapter"
local skemodule = require "hierarchy".skeleton

mathadapter.bind(
	"skeleton",
	function ()
        local bd_mt = skemodule.builddata_metatable()
		bd_mt.joint = math3d_adapter.getter(bd_mt.joint, "m", 3)
	end)