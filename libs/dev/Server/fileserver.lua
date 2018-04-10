local fileserver = {}

local fileprocess = require "fileprocess"
function fileserver.LIST(req)
    local path = req[2]
    if not path then
        return
    end


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
	local file_path = req[2]
	if not file_path then
		print("No file path found! Must input a file path")
        return
	end

    local client_hash = req[3]
    print("client hash:", client_hash)

    local server_hash = fileprocess.GetFileHash(file_path)

    if not server_hash then
        print("File not exist on server")
        return
    end
    if server_hash == client_hash then
        print("server hash", server_hash)
        print("client hash", client_hash)
        --no need to send file
        print("file "..file_path.." is up to date")
        return
    end

	local file = io.open(file_path, "rb")
	if not file then
        --file does not exist, reture a FILE command with nil hash
		return {"FILE", file_path}
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
        return {"ERROR","No file path found! Must input a file path"}
    end

    local file = io.open(file_path, "r")
    if not file then
        return {"EXIST_CHECK", "false"}
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

return fileserver
