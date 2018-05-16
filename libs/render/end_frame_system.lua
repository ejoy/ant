local ecs = ...
local world = ecs.world
local ru = require "render.util"
local bgfx = require "bgfx"
local baselib = require "bgfx.baselib"

--[@
ecs.component "frame_stat" {}
--@]

--[@
local end_frame_sys = ecs.system "end_frame"

end_frame_sys.singleton "frame_stat"

local lastcounter = nil
local function fps()
    local counter = baselib.HP_counter()
    local delta = 0
    if lastcounter then
        delta = counter - lastcounter 
    end

    lastcounter = counter

    local frequency = baselib.HP_frequency
    return delta and frequency / delta or 0
end

function end_frame_sys:update() 
    local stat = self.frame_stat
    stat.frame_num = bgfx.frame()

    stat.fps = fps()    -- we should call this function one time per second
    stat.ms = 1 / stat.fps
    --dprint("fps : ", stat.fps, ", ms : ", stat.ms)
end
--@]