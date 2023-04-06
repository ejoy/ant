local ecs = ...
local world = ecs.world
local w = world.w

local animodule = require "hierarchy".animation
local math3d 	= require "math3d"

local mathpkg	= import_package "ant.math"
local mc		= mathpkg.constant

local indirect_sys = ecs.system "indirect_system"

function indirect_sys:entity_init()
    for e in w:select "INIT stonemountain:in indirect?update" do
        e.indirect = true
    end
end