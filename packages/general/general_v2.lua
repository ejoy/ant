local ecs = ...
local w = ecs.world.w
local math3d = require "math3d"

local mc = import_package "ant.math".constant

local m = ecs.system "init_transform_system"
function m:entity_init()
    for v in w:select "INIT transform:in render_object:in" do
        v.render_object.srt = math3d.ref(v.transform and math3d.matrix(v.transform) or mc.IDENTITY_MAT)
    end
end