local iosys = require "iosys"
local id = "127.0.0.1:8888"

local io_ins = iosys.new()
local client_dir = "D:/Engine/ant/libs/dev/io/c/"

if not io_ins:Connect(id) then
   error("Connect error")
end

local function HandleResp()
    local pkg_table = io_ins:Get(id)
    for _, pkg in ipairs(pkg_table) do
        if pkg[1] == "FILE" then
            local full_path = client_dir .. pkg[2]
            local offset = pkg[4]
            local size = pkg[5]
            local data = pkg[6]

            local file
            if tonumber(offset) <= tonumber(PACKAGE_DATA_SIZE) then
                file = io.open(full_path, "wb")
            else
                file = io.open(full_path, "ab")
            end

            print("read file: " .. pkg[2] .. " progress: " .. tostring(offset) .. "/" .. tostring(size))

            if file then
                io.output(file)
                io.write(data)
                file:close()
            end
        else
            print("command not support", pkg[1])
        end
    end
end

io_ins:Send(id, {"Hello", "World"})
while true do
    local n_c, n_d = io_ins:Update()

    if n_c and #n_c > 0 then
        for k, v in ipairs(n_c) do
            print("new connection", k, v)
        end
    end

    if n_d and #n_d > 0 then
        for k, v in pairs(n_d) do
            print("need kick", k, v)
        end
    end

    HandleResp()
end