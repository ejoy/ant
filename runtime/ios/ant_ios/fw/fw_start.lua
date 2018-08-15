return function (window_handle, width, height, app_dir, bundle_dir)
    sand_box_dir = bundle_dir
    package_dir = app_dir

    g_WindowHandle = window_handle
    g_Width = width
    g_Height = height


    file_mgr:ReadDirStructure(sand_box_dir.."/Documents/dir.txt")
    file_mgr:ReadFilePathData(sand_box_dir.."/Documents/file.txt")


    package.loaded["winfile"].loadfile = loadfile
    package.loaded["winfile"].dofile = dofile
    package.loaded["winfile"].open = io.open

    package.loaded["winfile"].personaldir = function()
        return sand_box_dir.."/Documents"
    end
    package.loaded["winfile"].shortname = function()
        return "fileserver"
    end

    package.loaded["winfile"].exist = function(path, ignore_cache)
        if package.loaded["winfile"].attributes(path) then
            return true
        elseif file_exist_cache[path] and not ignore_cache then
            print("find file exist in cache: "..path)
            return true
        else
            --search on the server
            local request = {"EXIST", path }
            print("request file: "..path)

            linda:send("request", request)

            --wait here
            ---[[
            while true do
                local _, value = linda:receive(0.001, "file exist")
                if value ~= nil then
                    if value == "exist" then
                        print(path .. " exist")
                        file_exist_cache[path] = true
                        return true
                    elseif value == "not exist" then
                        print(path .. " not exist!! " .. tostring(value))
                        return false
                    elseif value == "diff hash" then
                        --hash is different, request the one on server
                        --return true if succeed
                        print("new request " .. path)
                        local file_request = {"GET", path}
                        linda:send("request", file_request)

                        --TODO file not exist
                        --wait here
                        while true do
                            local _, value = linda:receive(0.001, "new file")
                            if value then
                                print("received msg", path)
                                --put into the id_table and file_table
                                file_mgr:AddFileRecord(value[1], value[2])
                                print("add file recode: "..value[1] .. " and "..value[2])
                             --   file_mgr:WriteDirStructure(sand_box_dir.."/Documents/dir.txt")
                             --   file_mgr:WriteFilePathData(sand_box_dir.."/Documents/file.txt")

                                print("file name", path)
                                local real_path = file_mgr:GetRealPath(value[2])
                                real_path = sand_box_dir .. "/Documents/" .. real_path

                                --add to file exist cache
                                print("add to exist cache: "..path)
                                file_exist_cache[path] = true

                                return true
                            end
                        end
                    end

                    break
                end
            end
            --]]
        end

        return false
    end

    --init_lua_search_path(app_dir)

    --entrance = require "testlua"
    --entrance.init(window_handle, width, height)

    local client_io = lanes.gen("*", CreateIOThread)(linda, sand_box_dir)
end