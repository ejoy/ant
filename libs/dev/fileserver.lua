local fileserver = {}

function fileserver.LIST(req)
    local path = req[2]
    if not path then
        return
    end

    local file_process = require "fileprocess"

    local dir_table = file_process.GetDirectoryList(path)

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
		return {"No file path found! Must input a file path"}
	end
    --TODO: add hash check
    local client_hash = req[3]
    print("client hash:", client_hash)

    local file_process = require "fileprocess"
    local server_hash = file_process.GetFileHash(file_path)

    if server_hash == client_hash then
        print("server hash", server_hash)
        print("client hash", client_hash)
        --return {"You are OK, Bro"}
    end

	local file = io.open(file_path, "rb")
	if not file then
        --file does not exist, reture a FILE command with nil hash
		return {"FILE", file_path}
	end

	local file_size = file_process.GetFileSize(file)

	print("Pulling file", file_path, "filesize", file_size)

    local client_path = string.gsub(file_path, "ServerFiles", "ClientFiles")
    print("client file dir: ", client_path)

    if file_size < fileserver.MAX_PACKAGE_SIZE  then
        --if file is small enough to fit in one package, just return the file data
        --and the "FILE" command
        io.input(file)
        local file_data = io.read(file_size)
        io.close(file)
        return {"FILE", client_path, server_hash, file_size.."/"..file_size, file_data}
    else
        --otherwise, return a cmd tell the server to send multiple packages
        return {"MULTI_PACKAGE", file_path, client_path, file_size, server_hash}
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

    print("server file", file_path)
    local file = io.open(file_path, "r")
    if not file then
        return {"EXIST_CHECK", "false"}
    end

    io.close(file)

    local file_process = require "fileprocess"
    local server_hash = file_process.CalculateHash(file_path)
    if server_hash == req[3] then
        return {"EXIST_CHECK", "true"}
    else
        return {"EXIST_CHECK", "false"}
    end
end

return fileserver
