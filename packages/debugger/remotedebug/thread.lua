local thread = require "thread"

function thread.channel(name)
    local produce = thread.channel_produce(name)
    local consume = thread.channel_consume(name)
    return {
        push = function(_, ...) return produce:push(...) end,
        pop  = function(_, ...) return consume:pop(...)  end,
        bpop = function(_, ...) return consume:bpop(...) end,
    }
end

return thread
