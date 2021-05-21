local bake = require "bake"

local mathadapter_util = import_package "ant.math.adapter"
require "math3d"
local math3d_adapter = require "math3d.adapter"
mathadapter_util.bind("bake", function ()
    local ctx_mt = bake.context_metatable()
    ctx_mt.begin = math3d_adapter.getter(ctx_mt.begin, "vmm", 2)
end)