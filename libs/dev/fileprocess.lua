local fileprocess = {}

function fileprocess.GetFileSize(file)
    local current = file:seek()
    local size = file:seek("end")
    file:seek("set", current)
    return size
end

local MAX_CALC_CHUNK = 2 * 1024 --2k

function fileprocess.CalculateHash(file_path)
    --if haa local copy, hash calculation needed
    local file = io.open(file_path, "rb")
    if not file then
        return nil
    end

    --file is the handle
    local crypt = require "crypt"
    local file_size = fileprocess.GetFileSize(file)

    --file can be calculate only once
    if file_size <= MAX_CALC_CHUNK then
        local file_data = file:read_size(file_size)
        local sha1 = crypt.sha1(file_data)
        return crypt.hexencode(sha1)
    else
        --file too big, need multiple calculate
        --put the result into a temp file, than calculate them and get new hash value
        --read write between files
        local read_handle = file

        local cal_hash = true
        --the first time read data from target file
        --the second time and after read from temp file

        local final_hash = 0
        repeat
            local write_handle = io.tmpfile()

            file_size = fileprocess.GetFileSize(read_handle)
            --last calculation
            if file_size < MAX_CALC_CHUNK then
                cal_hash = false
            end

            local offset = 0

            --in this loop, cal all the data chunk(s)'s hash
            --put them in a file or return it
            repeat
                local remain_size = file_size - offset
                local read_size = 0
                if remain_size > MAX_CALC_CHUNK then
                    read_size = MAX_CALC_CHUNK
                else
                    read_size = remain_size
                end

                read_handle:seek("set", offset);
                local file_data = read_handle:read(read_size);
                local sha1 = crypt.sha1(file_data)
                sha1 = crypt.hexencode(sha1)

                if cal_hash then
               --     print("data chunk hash is", sha1)
                    write_handle:write(sha1)
                else
                    final_hash = sha1
                end

                offset = offset + MAX_CALC_CHUNK

            until offset >= file_size

            io.close(read_handle)
            read_handle = write_handle
        until cal_hash == false

        io.close(read_handle)
        return final_hash
    end
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
return fileprocess