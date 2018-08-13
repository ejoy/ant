dofile("libs/init.lua")

package.preload.lfs = function() return require "winfile" end
local client_dir = "libs/dev/io/c/"

local vfs = dofile "runtime/core/firmware/vfs.lua"
local client_repo = vfs.new( "runtime/core/firmware", client_dir )

local iosys = require "iosys"
local id = "127.0.0.1:8888"

local io_ins = iosys.new()

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

        elseif pkg[1] == "ROOT_HASH" then
            client_repo:changeroot(pkg[2])

        elseif pkg[1] == "REAL_PATH" then
            local real_path = pkg[2]

        else
            print("command not support", pkg[1])
        end
    end
end

io_ins:Send(id, {"REQUEST_ROOT"})
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

    while true do
        local pkg_table = io_ins:Get(id)
        for _, pkg in ipairs(pkg_table) do
            if pkg[1] == "ROOT_HASH" then
                client_repo:changeroot(pkg[2])
                break
            end
        end
    end

    local path = "a/a.txt"
    print("Read file", path)
    while true do
        local f, hash = client_repo:open(path)
        if f then
            return f
        end

        print("Try to request hash from server repo", hash)
        io_ins:Send(id, {"LOAD_HASH", hash})
        local realpath
        while true do
            local pkg_table = io_ins:Get(id)
            for _, pkg in ipairs(pkg_table) do
                if pkg[1] == "REAL_PATH" then
                    realpath = pkg[2]
                    break
                elseif pkg[1] == "HASH_ERROR" then
                    assert(false, "hash invalid")
                end
            end
        end

        io_ins:Send(id, {"GET", realpath})
    end

    HandleResp()
end