local ant = ...
local event = ant.event
local tag = ant.tag

function event.get_eid(tag_name)
    return tag(tag_name) : get_eid()
end

function event.link(tag_name, eid)
    tag(tag_name) : link(eid)
end

function event.get_parent(tag_name)
    return tag(tag_name) : get_parent()
end

function event.set_parent(tag_name, eid)
    tag(tag_name) : set_parent(eid)
end

function event.autoplay(tag_name, anim_name)
    tag(tag_name) : autoplay(anim_name)
end

function event.play(tag_name, anim_name)
    tag(tag_name) : play(anim_name)
end

function event.play_clip(tag_name, anim_name)
    tag(tag_name) : play_clip(anim_name)
end

function event.play_group(tag_name, anim_name)
    tag(tag_name) : play_group(anim_name)
end

function event.duration(tag_name, anim_name)
    return tag(tag_name) : duration(anim_name)
end

function event.time(tag_name, t)
    tag(tag_name) : time(t)
end

function event.speed(tag_name, t)
    tag(tag_name) : speed(t)
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

function event.set_clips(tag_name, clips)
    tag(tag_name) : set_clips(clips)
end

function event.get_clips(tag_name, clips)
    return tag(tag_name) : get_clips(clips)
end

function event.set_events(tag_name, anim_name, events)
    tag(tag_name) : set_events(anim_name, events)
end

function event.get_collider(tag_name, anim_name, time)
    return tag(tag_name) : get_collider(anim_name, time)
end

function event.remove()
    tag "*" : remove_all()
end