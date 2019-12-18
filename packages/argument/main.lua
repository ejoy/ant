local argument = {}
for _, e in ipairs(arg) do
    if e:sub(1,1) == '-' then
        local pos = e:find('=', 1, true)
        local k, v
        if pos then
            k = e:sub(2, pos-1)
            v = e:sub(pos+1)
        else
            k = e:sub(2)
            v = true
        end
        argument[k] = v
    end
end

return argument
