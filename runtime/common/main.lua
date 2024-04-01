local arguments = {} ; do
    local options = {}
    local i = 1
    while true do
        if arg[i] == nil then
            break
        elseif arg[i]:sub(1, 1) == "-" then
            options[arg[i]] = arg[i+1]
            i = i + 1
        else
            arguments[#arguments+1] = arg[i]
        end
        i = i + 1
    end
    arguments[0] = table.remove(arguments, 1)
    for k, v in pairs(options) do
        arguments[#arguments+1] = k
        arguments[#arguments+1] = v
    end
end

if arguments[0] == nil then
    return
end

arg = arguments

dofile "/engine/console/bootstrap.lua"
