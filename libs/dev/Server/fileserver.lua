local fileserver = {}

local function CalculateAbsolutePath(project_dir, relative_path)
    --or it is the relative path
    --if package_search_path has ../../.., need to go back to the upper directory
    local upper_dir_lvl = 0
    while true do
        local find_upper_dir = string.find(relative_path, "%.%./")
        if find_upper_dir == nil then
            --no more upper level needed to go
            break
        else
            upper_dir_lvl = upper_dir_lvl + 1
            relative_path = string.sub(relative_path, find_upper_dir + 3, -1)
        end
    end

    local rev_package_search = string.reverse(project_dir)
    for i = 1, upper_dir_lvl do
        local slash_pos = string.find(rev_package_search, "/")
        if slash_pos then
            rev_package_search = string.sub(rev_package_search, slash_pos + 1, -1)
        else
            break
        end
    end

    local search_dir = string.reverse(rev_package_search)
    return search_dir .. "/" .. relative_path
end

local fileprocess = require "fileprocess"
function fileserver.LIST(req)
    local path = req[2]
    if not path then
        return {"ERROR", "LIST", "path not found"}
    end

    print("path", path)
    local dir_table = fileprocess.GetDirectoryList(path)

    --no nil value between, should be OK
    local file_num = #dir_table
    --TODO: maintain the hash data of all files, minimize recalculation
    --for now just don't transform hash value

	return {"DIR", path, file_num, dir_table}
end

--pull a file from server to client, maybe invisible to client in the future
fileserver.MAX_PACKAGE_SIZE = 60*1024    --60k

function fileserver.GET(req)
    --req[1] is the command "GET"
    --req[2] is the file path
    --req[3] is the hash value, nil if client has no local cache
    local project_dir = req.project_dir
	local file_path = req[2]
	if not file_path then
		--print("No file path found! Must input a file path")
        return {"ERROR", "GET", "path not found"}
	end

    local client_hash = req[3]
    --print("client hash:", client_hash)

    local server_hash = fileprocess.GetFileHash(file_path)
    local absolute_path = file_path
    if not server_hash then
        --try under project_dir
        absolute_path =  CalculateAbsolutePath(project_dir, file_path)
        print("try this path", absolute_path)
        server_hash = fileprocess.GetFileHash(absolute_path)
    end
    --still can't find it, return
    if not server_hash then
        print("File not exist on server")

        return {"ERROR", "GET", "file:"..req[2].." not found"}
    end

    --print("server_hash", server_hash)
    if server_hash == client_hash then
        print("server hash", server_hash)
        print("client hash", client_hash)
        --no need to send file
        print("file "..file_path.." is up to date")
        return --ignore it
    end

	local file = io.open(absolute_path, "rb")
	if not file then
        return {"ERROR", "GET", "file:"..req[2].."not found"}
	end

	local file_size = fileprocess.GetFileSize(file)

	print("Pulling file", file_path, "filesize", file_size)

    --local client_path = string.gsub(file_path, "ServerFiles", "ClientFiles")
    print("client file dir: ", file_path)

    if file_size < fileserver.MAX_PACKAGE_SIZE  then
        --if file is small enough to fit in one package, just return the file data
        --and the "FILE" command
        io.input(file)
        local file_data = io.read(file_size)
        io.close(file)
        return {"FILE", file_path, server_hash, file_size.."/"..file_size, file_data}
    else
        --otherwise, return a cmd tell the server to send multiple packages
        return {"MULTI_PACKAGE", file_path, file_path, file_size, server_hash}
    end
end

function fileserver.EXIST(req)
    --req[1] is the command "EXIST"
    --req[2] is the file path
    --req[3] is the hash value of the client
    local file_path = req[2]
    if not file_path then
        return {"ERROR", "EXIST", "No file path found! Must input a file path"}
    end

    local file = io.open(file_path, "r")
    if not file then
        --try path with project directory path
        file = io.open(req.project_dir.."/"..file_path, "r")
        if not file then
            return {"EXIST_CHECK", "false"}
        end
    end

    io.close(file)
    --client does not have the file, return if the server has it
    if not req[3] then
        return {"EXIST_CHECK", "true"}
    end

    local server_hash = fileprocess.CalculateHash(file_path)
    if server_hash == req[3] then
        return {"EXIST_CHECK", "true"}
    else
        print("hash check fail")
        print(server_hash, req[3], file_path)
        return {"EXIST_CHECK", "false"}

    end
end

--this is the log client sends back
function fileserver.LOG(req)
    --req[1] is the command "LOG"
    --req[2] is the id of the client
    --req[3] is the label of the log TODO:(use for filtering etc. , leave it for now)
    --req[4] is the log text

    --for now, don't do any thing
    return req
end

--mainly for client requiring a file on server
--mostly is the same as GET, but need to search file according to package path
--and no "." allowed inside file name, will treat it as "/" as lua does
function fileserver.REQUIRE(req)
    --req[1] is the command "REQUIRE"
    --req[2] is the file name/path
    --req[3] is the package path
    --req.project_dir is the project directory

    local file_name = req[2]
    if not file_name then
        return {"ERROR", "REQUIRE", "No file name found! Must input a file name"}
    end

    local package_path = req[3]
    local project_dir = req.project_dir
    print("file name", file_name)
    print("package path", package_path)
    print("project_dir", project_dir)

    --replace "." with "/"
    local file_path = string.gsub(file_name,"%.", "/")
    local full_file_path = "" --the path we get

    print("file path", file_path)
    local start_pos = 1
    local file = nil
    local last_search = false
    --search the file here
    while true do
        local find_pos = string.find(package_path, ";", start_pos)
        local package_search_path = ""
        if find_pos then
            package_search_path = string.sub(package_path, start_pos, find_pos - 1)
            start_pos = find_pos + 1
        else
            package_search_path = string.sub(package_path, start_pos, -1)
            last_search = true
        end

        --"?" symbol will be replaced by file_name
        local package_search_path = string.gsub(package_search_path, "%?", file_path)
        --if the package_search_path is the path
        print("search for", package_search_path)
        file = io.open(package_search_path, "rb")
        if file then
            full_file_path = package_search_path
            break
        end

        --or it is the relative path
        --if package_search_path has ../../.., need to go back to the upper directory
        local search_name = CalculateAbsolutePath(project_dir, package_search_path)

        print("search for", search_name)
        file = io.open(search_name, "rb")
        if file then
            full_file_path = search_name
            break
        end

        --if every package paths have been searched and no file found, break
        if last_search then
            break
        end
    end

    if not file then
        --file does not exist, reture a FILE command with nil hash
        return {"ERROR", "REQUIRE", "file:"..full_file_path.." does not exist"}
    end

    local file_size = fileprocess.GetFileSize(file)

    print("Pulling file", full_file_path, "filesize", file_size)
    local server_hash = fileprocess.GetFileHash(full_file_path)
    if not server_hash then
        return {"ERROR", "REQUIRE", "file:"..full_file_path.." does not exist"}
    end

    file_path = file_path .. ".lua"
    --TODO server hash?
    if file_size < fileserver.MAX_PACKAGE_SIZE  then
        --if file is small enough to fit in one package, just return the file data
        --and the "FILE" command
        io.input(file)
        local file_data = io.read(file_size)
        io.close(file)
        --use file name correspond to the mem_file table keeps on client siede
        --print("FILE XX", file_name, server_hash, file_size)
        --use file path, from "render.hardware_interface" to "render/hardware_interface.lua
        return {"FILE", file_name, server_hash, file_size.."/"..file_size, file_data}
    else
        --otherwise, return a cmd tell the server to send multiple packages
        return {"MULTI_PACKAGE", full_file_path, file_name, file_size, server_hash, file_name}
    end
end

--get client sent screenshot
function fileserver.SCREENSHOT(req)
    return req
end
return fileserver
