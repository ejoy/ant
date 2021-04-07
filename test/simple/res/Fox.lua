local ant = ...
local event = ant.event
local tag = ant.tag

-- function event.birth()
--     tag "fox" : play_animation "Survey"
-- end

function event.autoplay(tag_name, anim_name)
    tag(tag_name) : autoplay(anim_name)
end