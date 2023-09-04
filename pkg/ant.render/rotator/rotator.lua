local ecs = ...
local world = ecs.world
local w     = world.w
local rsy = ecs.system "rotator_system"
local math3d	= require "math3d"
local ltask = require "ltask"

function rsy:render_submit()
    local function gettime()
        local _, now = ltask.now()
        return now
    end

    for e in w:select "rotator:in render_object:update scene:in" do
        local total_sec = tostring(e.rotator)
        local total_ms = total_sec * 1000
        local t = (gettime() % total_ms)/total_ms 
        local rad = math.rad(360*t)
        local ro = e.render_object
        local wm = ro.worldmat
        local cosy, siny = math.cos(rad), math.sin(rad)
        local rm = math3d.matrix({
            cosy, 0, siny, 0,
            0, 1, 0, 0,
            -siny, 0, cosy, 0,
            0, 0, 0, 1,
        })
        if wm ~= math3d.constant "null" then
            ro.worldmat = math3d.mul(rm, wm) 
        end
    end
end