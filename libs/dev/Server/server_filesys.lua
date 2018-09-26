local server_filesys = {}
server_filesys.__index = server_filesys

local enable_pack = false
function enable_pack_framework(state)
    if state then
        enable_pack = state
    end

    return enable_pack
end

function server_filesys.new(linda, root_dir)
    print("create new server filesys")
    local sp = setmetatable({linda = linda}, server_filesys)
    if root_dir then
        sp:Init(root_dir)
    end

    return sp
end

local fw = require "filewatch"
function server_filesys:Init(root_dir)
    local winfile = require "winfile"
    winfile.exist = function(path)
        if winfile.attributes(path) then
            return true
        end

        return false
    end

    winfile.open = io.open
    
    local vfsrepo = require "vfsrepo"
    self.vfs = vfsrepo.new()

    local res, err = pcall(self.vfs.init, self.vfs, root_dir)
    assert(res, "create server repo failed: " .. tostring(err))

    self.root_dir = root_dir
    print("create server repo successful")

    enable_pack_framework(true)

    ---[[
    --init filewatch
    --FIXME: for now only watch libs directory
    --TODO: mulitiple directory watching?
    local watch = assert(fw.add(root_dir.."/libs", "fdts"))
    self.fw_watch = watch
    --]]
end

local linda_func_body = {}
linda_func_body["repo_load"] = function(file_sys, hashkey)
    local real_path = file_sys.vfs:load(hashkey)
    
    file_sys.linda:send("repo_load_result"..hashkey, tostring(real_path))
end

linda_func_body["repo_root"] = function(file_sys)
    local server_root = file_sys.vfs:root_hash()
    file_sys.linda:send("repo_root_result", server_root)
end

local linda_func_name = {}
for k, _ in pairs(linda_func_body) do
    table.insert(linda_func_name, k)
end

function server_filesys:HandleLindaMsg()
    while true do
        local key, value = self.linda:receive(0.005, table.unpack(linda_func_name))
        if key then
            local func = linda_func_body[key]
            if func then
                func(self, value)
            end
        else
            break
        end
    end
end
local last_update_timer = os.clock()
function server_filesys:UpdateFileWatch()    
    while true do
        local id, type, path = fw.select()
        if id then
            print("fw", id, type, path)
            local time_step = os.clock() - last_update_timer
            if time_step > 10 then
                --update server_repo
                print("file modification detected, rebuild filesystem")
                local res, err = pcall(self.vfs.init, self.vfs, self.root_dir)
                assert(res, "update server repo failed: " .. tostring(err))
                print("build filesystem finished")
                last_update_timer = os.clock()
            end
        else
            break
        end
    end
end

function server_filesys:mainloop()
    self:HandleLindaMsg()
    self:UpdateFileWatch()
end

return server_filesys
