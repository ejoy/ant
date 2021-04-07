local ant = ...
local event = ant.event
local tag = ant.tag

function event.autoplay(tag_name, anim_name)
    tag(tag_name) : autoplay(anim_name)
end

function event.play(tag_name, anim_name)
    tag(tag_name) : play(anim_name)
end

function event.duration(tag_name, anim_name)
    return tag(tag_name) : duration(anim_name)
end

function event.time(tag_name, t)
    tag(tag_name) : time(t)
end

function event.set_position(tag_name, p)
    tag(tag_name) : set_position(p)
end

function event.set_rotation(tag_name, r)
    tag(tag_name) : set_rotation(r)
end

function event.set_scale(tag_name, s)
    tag(tag_name) : set_scale(s)
end

function event.get_position(tag_name)
    return tag(tag_name) : get_position()
end

function event.get_rotation(tag_name)
    return tag(tag_name) : get_rotation()
end

function event.get_scale(tag_name, s)
    return tag(tag_name) : get_scale()
end