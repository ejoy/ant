local vfsrepo_cloud = {}

vfsrepo_cloud.__index = vfsrepo_cloud

function vfsrepo_cloud.new(root_table)
    local r = setmetatable({}, vfsrepo_cloud)

    if root_table then
        r:init(root_table)
    end
    return r
end

local vfsrepo = require "vfsrepo"
function vfsrepo_cloud:init(root_table)
    local vfs_cloud = {}
    for _, v in ipairs(root_table) do
        vfs_cloud[v] = vfsrepo.new(v)
    end

    self.root_table = vfs_cloud
end

function vfsrepo_cloud:root_hash()
    local hash_table = {}
    for k, v in pairs(self.root_table) do
        hash_table[k] = v:root_hash()
    end

    return hash_table
end

function vfsrepo_cloud:load(hash, path)
    for dir, repo in pairs(self.root_table) do
        local s_pos, e_pos = string.find(path, dir)
        if s_pos and e_pos then
            local real_path = repo:load(hash)
            if real_path then
                if string.find(real_path, dir) then
                    return real_path
                else
                    return dir .. "/" .. real_path
                end
            end
        end
    end
end

return vfsrepo_cloud