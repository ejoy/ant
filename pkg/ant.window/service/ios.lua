local ltask = require "ltask"
local exclusive = require "ltask.exclusive"
local window = require "window.ios"

local scheduling = exclusive.scheduling()
local SCHEDULE_SUCCESS <const> = 3

local function update()
    repeat
        scheduling()
    until ltask.schedule_message() ~= SCHEDULE_SUCCESS
end
window.init({}, update)
ltask.fork(function()
    window.mainloop()
    update()
end)

local S = {}
return S
