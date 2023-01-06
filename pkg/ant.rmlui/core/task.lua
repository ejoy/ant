local m = {}

local lst = {}

function m.new(f)
    lst[#lst+1] = f
end

function m.update()
    for i = 1, #lst do
        lst[i]()
        lst[i] = nil
    end
end

return m
