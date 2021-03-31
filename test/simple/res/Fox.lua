local ant = ...
local event = ant.event
local tag = ant.tag

function event.birth()
    tag "fox" : play_animation "Survey"
end
