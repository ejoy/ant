local vfs_cloud = {}
vfs_cloud.__index = vfs_cloud

--one firmware directory, a list of remote directory
--element in dir_table should be independent(not a subdirectory inside other element)
function vfs_cloud.new(firmware, dir_table)
    local vfs = require "firmware.vfs"
    local vfs_table = {}

    for k, v in pairs(dir_table) do
        local remote_dir_path = v
        vfs_table[k] = vfs.new(firmware, remote_dir_path)
    end

    return setmetatable({vfs_table = vfs_table}, vfs_cloud)
end

function vfs_cloud:changeroot(table_of_root)
    print("change root!!!!!", table_of_root)
    for k, v in pairs(table_of_root) do
        print("root is", k, v)
        local repo = self.vfs_table[k]
        if repo then
            repo:changeroot(v)
        end
    end
end

function vfs_cloud:open(path)
    for remote_dir, repo in pairs(self.vfs_table) do
        local s_pos, e_pos = string.find(path, remote_dir)
        if s_pos and e_pos then
            --is in this sub repo
            local sub_repo_path = string.sub(path, e_pos+1)
            return repo:open(sub_repo_path)
        end
    end
end

function vfs_cloud:write(file_path, hash, content, mode)
    for remote_dir, repo in pairs(self.vfs_table) do
        local s_pos, e_pos = string.find(file_path, remote_dir)
        if s_pos and e_pos then
            repo:write(hash, content, mode)
        end
    end
end

return vfs_cloud