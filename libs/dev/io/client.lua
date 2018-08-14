dofile("libs/init.lua")

package.preload.lfs = function() return require "winfile" end
local lfs = require "lfs"
local client_dir = "libs/dev/io/c"
local filesystem_path = require "filesystem.path"
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

local function CreateFolder(full_path)
    local folder_name = filesystem_path.parent(full_path)
    if lfs.attributes(folder_name) then
        return
    end

    local parent_name = folder_name
    local file_name = ""
    while not lfs.attributes(parent_name) do
        file_name = filesystem_path.filename(parent_name)
        parent_name = filesystem_path.parent(parent_name)
    end

    lfs.mkdir(parent_name .. "/" .. file_name)
    print("make dir: "..parent_name .. "/" .. file_name)


    CreateFolder(full_path)
end

io_ins:Send(id, {"REQUEST_ROOT"})
--while true do
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

    local root_changed = false
    while not root_changed do
        local n_c, n_d = io_ins:Update()
        local pkg_table = io_ins:Get(id)
        for _, pkg in ipairs(pkg_table) do
            if pkg[1] == "ROOT_HASH" then
                local client_root = pkg[2]
                print("change root", client_root)
                client_repo:changeroot(client_root)
                root_changed = true
                break
            end
        end
    end

    local path = "f0/doc.md"
    print("Read file", path)
    while true do
        local n_c, n_d = io_ins:Update()
        local f, hash = client_repo:open(path)
        if f then
            print("load file: "..path.." finished")
            return f
        elseif hash then
            print("still need file with hash: " .. hash)
        else
            assert(false, "f: "..tostring(f).." hash: "..tostring(hash))
        end

        print("Try to request hash from server repo", hash)
        io_ins:Send(id, {"LOAD_HASH", hash})
        local realpath
        while not realpath do
            local n_c, n_d = io_ins:Update()
            local pkg_table = io_ins:Get(id)
            for _, pkg in ipairs(pkg_table) do
                if pkg[1] == "REAL_PATH" then
                    realpath = pkg[2]
                    break
                elseif pkg[1] == "HASH_ERROR" then
                    print("hash invalid")
                    assert(false, "hash invalid")
                else
                    print("cmd not found", pkg[1])
                end
            end
        end

        print("get realpath file", realpath)
        io_ins:Send(id, {"GET", realpath})

        local get_file_server = false
        while not get_file_server do
            local n_c, n_d = io_ins:Update()
            local pkg_table = io_ins:Get(id)
            for _, pkg in ipairs(pkg_table) do
                if pkg[1] == "FILE" then
                    local full_path = client_dir .. pkg[2]
                    local offset = pkg[4]
                    local size = pkg[5]
                    local data = pkg[6]

                    CreateFolder(full_path)

                    client_repo:write(hash, pkg[6])
                    --[[
                    local file
                    if tonumber(offset) <= tonumber(PACKAGE_DATA_SIZE) then
                        file = io.open(full_path, "wb")
                    else
                        file = io.open(full_path, "ab")
                    end

                    print("read file: " .. pkg[2] .. " progress: " .. tostring(offset) .. "/" .. tostring(size))
                    print("file path: " .. full_path, filesystem_path.parent(full_path))


                    if file then
                        io.output(file)
                        io.write(data)
                        file:close()

                    else
                        print("!!!NO FILE!!!")
                    end
--]]
                    get_file_server = true
                    break
                end
            end
        end

        print("client get file from server: "..realpath )
    end
--end