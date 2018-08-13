dofile("libs/init.lua")

local server_dir = "libs/dev/io/s/"

local vfsrepo = require "vfsrepo"
local server_repo = vfsrepo.new()
server_repo:init("server_dir")

local iosys = require "iosys"

local io_ins = iosys.new()


local id = "127.0.0.1:8888"
if not io_ins:Bind(id) then
    error("Bind error")
end

local id_table = {}

local function SendFile(c_id, file_path)
    local full_path = server_dir .. file_path
    local file = io.open(full_path, "rb")
    print("file full path", full_path)
    if file then
        io.input(file)
        local data = file:read("a")
        file:close()

        local d_size = #data
        print("get data: ", d_size)

        local offset = 1
        while offset < d_size do
            local read_back = math.min(offset + PACKAGE_DATA_SIZE - 1, d_size)
            local package_string = string.sub(data, offset, read_back)
            local hash = "NAN"

            io_ins:Send(c_id, {"FILE", file_path, hash, read_back, d_size, package_string})

            offset = read_back + 1
        end
    end
end

local function HandleRequest(c_id, req)
    if req[1] == "REQUEST_ROOT" then
        local root_hash = server_repo:root_hash()
        io_ins:Send(c_id, {"ROOT_HASH", root_hash})

    elseif req[1] == "LOAD_HASH" then
        local realpath = server_repo:load(req[2])
        if realpath then
            io_ins:Send(c_id, {"REAL_PATH", realpath})
        else
            io_ins:Send(c_id, {"HASH_ERROR"})
        end

    elseif req[1] == "GET" then
        local file_path = req[2]
        SendFile(c_id, file_path)
    end
end

while true do

    local n_c, n_d = io_ins:Update()

    --handle new connection
    if n_c and #n_c > 0 then
        for _, v in ipairs(n_c) do
            print("new id connect "..v)

            table.insert(id_table, v)
        end
    end

    --handle new disconnection
    if n_d and #n_d > 0 then
        for _, v in ipairs(n_d) do
            print("id disconnected "..v)

            for k, d_id in ipairs(id_table) do
                if d_id == v then
                    table.remove(id_table, k)
                    break
                end
            end

        end
    end

    for _, c_id in ipairs(id_table) do
        --receive pkg
        local pkg = io_ins:Get(c_id)
        if pkg then
            for _, data in ipairs(pkg) do

                HandleRequest(c_id, data)
                --[[
                if data then
                    SendFile(c_id, "doc.md")
                end
                --]]
            end
        end

        --SendFile(c_id, "doc.md")
        --send pkg
        --[[
        io_ins:Send(c_id, {"Yes", "Hello"})
        io_ins:Send(c_id, {"can you get this?"})
        io_ins:Send(c_id, {"how about this?"})
        --]]
    end
end

