local ltask = require "ltask"

local m = {}

function m.new()
    return {}
end

function m.add(t, f)
    t[#t+1] = {f}
end

function m.wait(t)
    for _ in ltask.parallel(t) do
    end
end

return m
