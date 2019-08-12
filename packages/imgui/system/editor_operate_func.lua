local t = {}

function t.handle_event(world,event,args)
    local handle_func = t.handler[event]
    assert(handle_func,"event not exist:"..event)
    if handle_func then
        return handle_func(world,args)
    end
end

t.handler = {}
function t.handler.Delete(world,args)
    for _,id in ipairs(args) do
        world:remove_entity(id)
    end
end

return t.handle_event