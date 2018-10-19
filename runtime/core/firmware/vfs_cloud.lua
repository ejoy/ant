local vfs_cloud = {}
vfs_cloud.__index = vfs_cloud

--one firmware directory, a list of remote directory
--element in dir_table should be independent(not a subdirectory inside other element)
function vfs_cloud.new(firmware, dir_table)
    local vfs = require "firmware.vfs"

    local path_util = require "filesystem.path"

    local vfs_table = {}
    local subdir_count = 0
    for k, v in pairs(dir_table) do
        -- check if v(remote_path) is dir and exist, if not exist then create dir
        path_util.create_dirs(v)
        
        vfs_table[k] = vfs.new(firmware, v)
        subdir_count = subdir_count + 1
    end

    print("create vfs cloud finished")
    return setmetatable({vfs_table = vfs_table, subdir_count = subdir_count}, vfs_cloud)
end

function vfs_cloud:changeroot(root_hash, vfs_dir)
    local repo = self.vfs_table[vfs_dir]
    if repo then
        print("change root: " .. root_hash)
        local res, error = pcall(repo.changeroot, repo, root_hash)
        if not res then
            print(res, error)
            return res, error
        end

        if not self.changeroot_count then
            self.changeroot_count = 1
        else
            self.changeroot_count = self.changeroot_count + 1
        end
        return true
    else
        print("repo: " .. vfs_dir .. " dose not exist, we have")
        for k, v in pairs(self.vfs_table) do
            print(k, v)
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

function vfs_cloud:write(hash, content, file_path, mode)
    for remote_dir, repo in pairs(self.vfs_table) do
        local s_pos, e_pos = string.find(file_path, remote_dir)
        if s_pos and e_pos then
            repo:write(hash, content, mode)
        end
    end
end

function vfs_cloud:changeroot_finished()
    if self.changeroot_count == self.subdir_count then
        return true
    else
        return false
    end
end

return vfs_cloud