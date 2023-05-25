local ltask = require "ltask"
local fmod = require "fmod"

local instance = fmod.init()
local background = instance:background()
local event_list = {}

local S = {}

function S.load(banks)
    for _, f in ipairs(banks) do
        instance:load_bank(f, event_list)
    end
end

local worker = {}
local worker_num = 0
local worker_cur = 0
local worker_frame = 0

function S.worker_init()
    local who = ltask.current_session().from
    worker[who] = nil
    worker_num = worker_num + 1
end

function S.worker_exit()
    local who = ltask.current_session().from
    if worker[who] == worker_frame then
        worker_cur = worker_cur - 1
    end
    worker[who] = nil
    worker_num = worker_num - 1
end

local cmd = {}

function cmd.play(event_name)
    fmod.play(event_list[event_name])
end

function cmd.play_background(event_name)
    background:play(event_list[event_name])
end

function cmd.stop_background(fadeout)
    background:stop(fadeout)
end

local function submit(cmdqueue)
    if cmdqueue == nil then
        return
    end
    for i = 1, #cmdqueue do
        local v = cmdqueue[i]
        cmd[v[1]](table.unpack(v, 2, #v))
    end
end

local function frame()
    worker_frame = worker_frame + 1
    worker_cur = 0
    instance:update()
end

function S.worker_frame(cmdqueue)
    local who = ltask.current_session().from
    if worker[who] ~= worker_frame then
        worker[who] = worker_frame
        worker_cur = worker_cur + 1
        submit(cmdqueue)
        if worker_cur == worker_num then
            frame()
        end
    end
end

function S.quit()
    background:stop()
    instance:shutdown()
    ltask.quit()
end

return S
