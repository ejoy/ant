local ltask = require "ltask"

local m = {}

function m.new()
    return {}
end

function m.add(t, f)
    t[#t+1] = {f}
end

function m.wait(t)
    for _, resp in ltask.parallel(t) do
        if resp.error then
            resp:rethrow()
        end
    end
end

return m
