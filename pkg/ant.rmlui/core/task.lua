local m = {}

local tasks = {}

function m.new(f)
    tasks[#tasks+1] = f
end

function m.update()
    local lst = tasks
    tasks = {}
    for i = 1, #lst do
        lst[i]()
        lst[i] = nil
    end
end

return m
