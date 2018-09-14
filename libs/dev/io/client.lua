dofile("libs/init.lua")
package.path = package.path .. ";runtime/core/?.lua;libs/dev/common/?.lua;"
local PACKAGE_DATA_SIZE = 60*1024
package.preload.lfs = function() return require "winfile" end
local lfs = require "lfs"
local client_dir = "libs/dev/io/c"
local filesystem_path = require "filesystem.path"

--local vfs = require "firmware.vfs"
--local client_repo = vfs.new( "runtime/core/firmware", client_dir )

local dir_table = {"libs/dev/io/s/f0", "libs/dev/io/s/f1"}
local vfs_cloud = require "firmware.vfs_cloud"
local repo_cloud = vfs_cloud.new("runtime/core/firmware", dir_table)


local iosys = require "iosys"
local id = "127.0.0.1:8888"

local io_ins = iosys.new()

if not io_ins:Connect(id) then
   error("Connect error")
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

    local root_changed = 0
    while root_changed < #dir_table do
        local n_c, n_d = io_ins:Update()
        local pkg_table = io_ins:Get(id)
        for _, pkg in ipairs(pkg_table) do
            if pkg[1] == "ROOT_HASH" then
                local client_dir = pkg[2]
                local client_root = pkg[3]
                print("change root", client_dir, client_root)
                if repo_cloud:changeroot(client_root, client_dir) then
                    root_changed = root_changed + 1
                end
                --client_repo:changeroot(client_root)
                break
            end
        end
    end

    local path = "libs/dev/io/s/f1/foo.lua"
    print("Read file", path)
    while true do
        local n_c, n_d = io_ins:Update()

        --local f, hash = client_repo:open(path)
        local f, hash = repo_cloud:open(path)
        if f then
            print("load file: "..path.." finished")
            local f_content = f:read("a")
            print(f_content)
            f:close()
            return
        elseif hash then
            print("still need file with hash: " .. hash)
        else
            assert(false, "f: "..tostring(f).." hash: "..tostring(hash))
        end

        print("Try to request hash from server repo", hash)
        io_ins:Send(id, {"LOAD_HASH", hash, path})
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
                    print("get package",#pkg[6])
                    --client_repo:write(hash, pkg[6])
                    repo_cloud:write(hash,pkg[6],path)

                    get_file_server = true
                    break
                end
            end
        end

        print("client get file from server: "..realpath )
    end
--end