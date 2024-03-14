local ltask = require "ltask"
local exclusive = require "ltask.exclusive"
local window = require "window.ios"

local scheduling = exclusive.scheduling()
local SCHEDULE_SUCCESS <const> = 3
local CALL = false
local function update()
    ltask.wakeup "update"
    repeat
        scheduling()
    until ltask.schedule_message() ~= SCHEDULE_SUCCESS
    while CALL do
        exclusive.sleep(1)
        repeat
            scheduling()
        until ltask.schedule_message() ~= SCHEDULE_SUCCESS
    end
end
window.init({}, update)
ltask.fork(function()
    window.mainloop()
    update()
end)

local S = {}

function S.maxfps(fps)
end

return S
