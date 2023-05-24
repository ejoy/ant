local banks = ...

local ltask = require "ltask"
local fmod = require "fmod"
local fs = require "filesystem"

local instance = fmod.init()
local event_list = {}
for _, f in ipairs(banks) do
    local localf = fs.path(f):localpath():string()
    instance:load_bank(localf, event_list)
end

local S = {}

function S.play(event_name)
    fmod.play(event_list[event_name])
end

function S.quit()
    instance:shutdown()
    ltask.quit()
end

ltask.fork(function()
    while true do
        ltask.sleep(100)
        instance:update()
    end
end)

return S
