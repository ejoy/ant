package.path = "../?/?.lua;" .. package.path
local lanes = require "lanes"
if lanes.configure then lanes.configure() end

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

function fileprocess.GetFileHash(path)
    return fileprocess.file_hash_table[path]
end

--use stream from crypt module
local MAX_CALC_CHUNK = 64 * 1024 --64K
local crypt_encoder = nil
function fileprocess.CalculateHash(file_path)
    --if have local copy, hash calculation needed
    local file = io.open(file_path, "rb")
    if not file then
        return nil
    end

    --file is the handle
    local crypt = require "crypt"
    if not crypt_encoder then
        crypt_encoder = crypt.sha1_encoder():init()
    end

    local file_size = fileprocess.GetFileSize(file)

    --file can be calculate only once
    repeat
        local read_size = 0
        if file_size < MAX_CALC_CHUNK then
            read_size = file_size
        else
            read_size = MAX_CALC_CHUNK
        end

        local file_data = file:read(read_size)
        crypt_encoder:update(file_data)

        file_size = file_size - read_size
    until file_size <= 0

    return crypt.hexencode(crypt_encoder:final())
end

function fileprocess.GetDirectoryList(path)
    local myfile = io.popen("dir "..path .. [[ /b ]], "r")
    if not myfile then
        print("open file for dir failed")
        return
    end

    local dir_table = {}
    for cnt in myfile:lines() do
        table.insert(dir_table, cnt)
    end
    myfile:close()
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