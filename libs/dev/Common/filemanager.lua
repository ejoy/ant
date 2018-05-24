--used to manager the client files
local filemanager = {}; filemanager.__index = filemanager

function filemanager.new()
    return setmetatable({}, filemanager)
end

local id_table = {}
id_table[0] = {}
local file_table = {}

--root is 0, next dir id start at 1
local next_dir_id = 1

function filemanager:ReadDirStructure(path)

    local structure_file = io.open(path, "r", true)
    if not structure_file then
        --no file then create a new one
      --  print("dir file path", path)
        local dir_path = io.open(path, "w", true)

        io.close(dir_path)
        return
    end

    local current_id = -1
    for line in structure_file:lines() do
        local id = tonumber(line)
        --print("id",id)
        if id then
            --got the id of a new dir table
            current_id = id
            id_table[current_id] = {}
            if current_id > next_dir_id then
                next_dir_id = current_id    --find the bigger one
            end
        else
            --got the data for current dir table
            local split_pos = string.find(line, " ")
            --print("pos",split_pos)
            local name = string.sub(line, 1, split_pos - 1)
            local hash_id = string.sub(line, split_pos + 1)
            id_table[current_id][name] = hash_id
        end
    end

    --next dir id will be 1 bigger than the current max id
    next_dir_id = next_dir_id + 1

    --if no root, create one
    if not id_table[0] then
        id_table[0] = {}
    end

    structure_file:close()
end

function filemanager:WriteDirStructure(path)
    local file = io.open(path, "w")
    io.output(file)
    for id, file_table in pairs(id_table) do
        io.write(id.."\n")
     --   print("id:", id)
        for name, hash in pairs(file_table) do
      --      print("name",name, hash)
            io.write(name .." "..hash.."\n")
        end
    end
    file:close()
end

function filemanager:ReadFilePathData(path)
    local file = io.open(path, "r", true)
    if not file then
        local file_path = io.open(path, "w", true)
        io.close(file_path)
        return
    end

    for line in file:lines() do
        local split_pos = string.find(line, " ")
        local hash = string.sub(line, 1, split_pos - 1)
        local filepath = string.sub(line, split_pos + 1)

        file_table[hash] = filepath
    end

    file:close()
end

function filemanager:WriteFilePathData(path)
    local file = io.open(path, "w")
    io.output(file)
    for hash, real_path in pairs(file_table) do
        io.write(hash.." "..real_path.."\n")
   --     print("hash real_path:", hash .. " " .. real_path)
    end
    file:close()
end

function filemanager:GetRealPath(path)
    --1 is the "/" most likely
    local start_pos = 2
    local search_id = 0 --root
    while true do
        local slash_pos = string.find(path, "/", start_pos)
        local dir = ""
        if not slash_pos then
            --means it's the last bit
            dir = string.sub(path, start_pos)
        else
            dir = string.sub(path, start_pos, slash_pos-1)
        end
        --print("dir ", dir)
        local hash_id = id_table[search_id][dir]

       -- print("id_table", search_id, id_table[search_id], hash_id)
        if not hash_id then
            return nil
        end

        local id = tonumber(tostring(hash_id))
       -- print("id ", id)
        if not id then
            --not a number, means found the file
            --print("found file", hash_id, file_table[hash_id])
            return file_table[hash_id]
        end

        --and id, means it is a dir
        search_id = id
        start_pos = slash_pos + 1
    end
end

--add a file, update the id_table and file_table
function filemanager:AddFileRecord(hash, path)
    local start_pos = 2
    --start from root
    local search_id = 0
    while true do
        local slash_pos = string.find(path, "/", start_pos)
        local dir = ""
        if not slash_pos then
            dir = string.sub(path, start_pos)
        else
            dir = string.sub(path, start_pos, slash_pos-1)
        end
        local file_id = id_table[search_id][dir]

        --id_table[search_id] must be valid, it starts with root 0
        --the file_id may be nil, then we need to create new dir/file id
        if not file_id then
            --print("not found ",search_id, dir)
            if slash_pos then
                --dir is a directory, not the filename
                id_table[search_id][dir] = next_dir_id
                id_table[next_dir_id] = {}  --create a new table
                search_id = next_dir_id
                next_dir_id = next_dir_id + 1
            else
                --set the new hash id there
                id_table[search_id][dir] = hash
                break
            end
        else
            --print("found", search_id, dir, file_id)
            local id = tonumber(tostring(file_id))
            if not id then
                --already have a hash value here, then it will be covered by the new one
                id_table[search_id][dir] = hash
                break
            else
                --it is a dir id, we will go deeper next
                search_id = id
            end
        end

        start_pos = slash_pos + 1
    end

    local real_path = string.sub(hash, 1, 3) .. "/" .. hash

    file_table[hash] = real_path
end

return filemanager