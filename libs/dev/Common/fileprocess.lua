package.path = "../?/?.lua;" .. package.path
local lanes = require "lanes"
if lanes.configure then lanes.configure() end

local filesystem = require "winfile"

local fileprocess = {}

function fileprocess.GetFileSize(file)
    local current = file:seek()
    local size = file:seek("end")
    file:seek("set", current)
    return size
end


--for now just put it here
fileprocess.hashfile = "hashtable"
fileprocess.dir_path = "ServerFiles"

fileprocess.time_stamp_table = {}
fileprocess.file_hash_table = {}

--use stream from crypt module
fileprocess.MAX_CALC_CHUNK = 64 * 1024 --64K
local crypt_encoder = nil
function fileprocess.CalculateHash(file_path)
    --if have local copy, hash calculation needed
    local file = io.open(file_path, "rb")
    if not file then
        return nil
    end

    --file is the handle
    local crypt = require "crypt"
    crypt_encoder = crypt.sha1_encoder():init()

    local file_size = fileprocess.GetFileSize(file)
    print(file_size)
    --file can be calculate only once
    repeat
        local read_size = 0
        if file_size < fileprocess.MAX_CALC_CHUNK then
            read_size = file_size
        else
            read_size = fileprocess.MAX_CALC_CHUNK
        end

        local file_data = file:read(read_size)
        crypt_encoder:update(file_data)

        file_size = file_size - read_size
    until file_size <= 0

    local result = crypt.hexencode(crypt_encoder:final())
    return result
end

function fileprocess.GetFileHash(path)

    local file_hash = fileprocess.file_hash_table[path]
    if not file_hash then
        file_hash = fileprocess.CalculateHash(path)
        fileprocess.file_hash_table[path] = file_hash
    end
    return file_hash
end

function fileprocess.GetDirectoryList(path)
    local dir_table = {}
    local iter, dir_obj = filesystem.dir(path)

    while true do
        local dir_name = iter(dir_obj)
        if not dir_name then
            break
        end

        --not including these two
        if dir_name ~= "." and dir_name ~=".." then
            table.insert(dir_table, dir_name)
        end
    end

    return dir_table
end

function fileprocess.GetLastModificationTime(path)
    local f = io.popen("stat -c %Y "..path)
    local last_modification = f:read()
    --print(os.date("%c", last_modification))
    return last_modification
end

local function WriteHashFile(path)
    local file_hash = io.open(fileprocess.hashfile, "w+")
    io.output(file_hash)
    for filename, time_stamp in pairs(fileprocess.time_stamp_table) do

        io.write(filename.."\n")
        io.write(time_stamp.."\n")
        local hash_value = fileprocess.file_hash_table[filename]

        --directory use nil as hash value
        if not hash_value then
            io.write("nil\n")
        else
            io.write(hash_value.."\n")
        end

    end

    io.close(file_hash)
end

fileprocess.hashfile_writer = lanes.gen("io",
function (file_path, time_stamp_table, file_hash_table)
    local file_hash = io.open(file_path, "w+")
    io.output(file_hash)
    for filename, time_stamp in pairs(time_stamp_table) do

        io.write(filename.."\n")
        io.write(time_stamp.."\n")
        local hash_value = file_hash_table[filename]

        --directory use nil as hash value
        if not hash_value then
            io.write("nil\n")
        else
            io.write(hash_value.."\n")
        end

    end
    io.close(file_hash)
end
)


function fileprocess:UpdateHashFile()
    local file_path = self.hashfile
    local time_stamp = self.time_stamp_table
    local hash_table = self.file_hash_table
    return fileprocess.hashfile_writer(file_path, time_stamp, hash_table)[1]
end

return fileprocess