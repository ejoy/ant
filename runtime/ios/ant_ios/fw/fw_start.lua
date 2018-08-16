return function (window_handle, width, height, app_dir, bundle_dir)
    sand_box_dir = bundle_dir
    package_dir = app_dir

    g_WindowHandle = window_handle
    g_Width = width
    g_Height = height

    package.loaded["winfile"].loadfile = loadfile
    package.loaded["winfile"].dofile = dofile
    package.loaded["winfile"].open = io.open

    package.loaded["winfile"].personaldir = function()
        return sand_box_dir.."/Documents"
    end
    package.loaded["winfile"].shortname = function()
        return "fileserver"
    end

    package.loaded["winfile"].exist = function(path)
        if package.loaded["winfile"].attributes(path) then
            return true
        else
            while true do
                --todo a exist api??
                ---for now, will pull all file
                linda:send("vfs_open", path)
                local file, hash
                while true do
                    local key, val = linda:receive(0.001, "vfs_open_res")
                    if val then
                        file, hash = val[1], val[2]
                        break
                    end
                end
                --local file, hash = client_repo:open(path)

                if file then
                    print("get file", file, path)
                    return true
                end

                assert(hash, "vfs system error: no file and no hash", path)

                print("Try to request hash from server", hash)
                local request = {"EXIST", hash}
                linda:send("request", request)

                local realpath
                while not realpath do
                    local _, value = linda:receive(0.001, "file exist")
                    if value == "not exist" then
                        --not such file on server
                        print("error: file "..filename.." can't be found")
                        return false
                    else
                        realpath = value
                    end
                end

                --value is the real path
                request = {"GET", realpath, hash}
                linda:send("request", request)
                -- get file
                while true do
                    local _, file_value = linda:receive(0.001, "new file")
                    if file_value then
                        --file_value should be local address
                        --client_repo:write should be called in io thread
                        break
                    end
                end
            end
        end

        return false
    end

    --entrance = require "testlua"
    --entrance.init(window_handle, width, height)

    local client_io, err = lanes.gen("*", CreateIOThread)(linda, package_dir, sand_box_dir)
    if not client_io then
        print("lanes error: ", err)
    else
        client_repo = true
    end
end