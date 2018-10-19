local ecs = ...
local world = ecs.world

local vfs_repo_system = ecs.system "vfs_repo_system"
vfs_repo_system.singleton "vfs_update_component"
vfs_repo_system.singleton "vfs_root_component"
vfs_repo_system.singleton "vfs_load_component"

local fs = require "filesystem"

local enable_pack = false
local function enable_pack_framework(state)
    if state then
        enable_pack = state
    end

    return enable_pack
end

local function rebuild_vfs_repo(self)
    local rebuild_start = os.clock()
    print("rebuild filesystem", type(self.root_dir), self.root_dir)
    
    local res, content = pcall(self.vfs.init, self.vfs, self.root_dir, self.localcache)
    if not res then
        print("build virtual repo failed", content)
        return
    end
    --assert(res, "build virtual repo failed: "..tostring(content))

    self.localcache = content

    local rebuild_end = os.clock()
    print("build filesystem finished, cost time:", rebuild_end - rebuild_start)
    last_update_timer = rebuild_end
end

function vfs_repo_system:init()
    local vfsrepo = require "vfsrepo"
    self.vfs = vfsrepo.new()
    self.root_dir = "."

    rebuild_vfs_repo(self)

    self.vfs_root_component.root = self.vfs:root_hash()
    enable_pack_framework(true)
end

local last_update_timer = os.clock()
local min_update_time = 5.0

local function check_rebuild(self)
    local need_update = self.vfs_update_component.do_update
    local time_step = os.clock() - last_update_timer
    if need_update and time_step > min_update_time then
        print("file modification detected")
        rebuild_vfs_repo(self)
        
        self.vfs_update_component.do_update = false
    end
end

local function check_load_request(self)
    local load_req = self.vfs_load_component.load_request_queue
    for hash, t in pairs(load_req) do
        --print(pcall(self.vfs.load, self.vfs, hash))
        
        t.real_path = self.vfs:load(hash)
    end
end

function vfs_repo_system:update()
    check_rebuild(self)
    check_load_request(self)
end
