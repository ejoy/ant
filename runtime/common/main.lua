local i = 1
while true do
    if arg[i] == '-E' then
    elseif arg[i] == '-e' then
        i = i + 1
        assert(arg[i], "'-e' needs argument")
        load(arg[i], "=(expr)")()
    else
        break
    end
    i = i + 1
end

if arg[i] == nil then
    return
end

for j = -1, #arg do
    arg[j - i] = arg[j]
end
for j = #arg - i + 1, #arg do
    arg[j] = nil
end
assert(loadfile(arg[0]))(table.unpack(arg))
