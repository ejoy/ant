local fw = require "filewatch"
local class = require "common.class"
local fs = require "filesystem"
local localfs = require "filesystem.local"
local gui_util = require "editor.gui_util"
local gui_mgr = require "gui_mgr"
local FileWatchMgr = class("FileWatchMgr")

function  FileWatchMgr:_init()
    local gui_mgr = require "gui_mgr"
    self.fw_id = nil
    self.IDX = 0
    self.size = 0
    self.path_tbl = {}--<folder,target>
    ---
    local current_path = localfs.current_path()
    self.root_path = current_path:string()
    gui_mgr.register_update(self.update,self)
end


function FileWatchMgr:add_pkg_path_watch(pkg_path,cb)
    assert(pkg_path)
    assert(cb)
    --prepare path
    if type(pkg_path) == "string" then
        pkg_path = fs.path(pkg_path)
    end
    local pattern = nil
    local local_target_path = gui_util.pkg_path_to_local(pkg_path,true)
    local path_size = #local_target_path
    local is_dir = false
    if fs.is_directory(pkg_path) then
        pattern = string.format("^%s/",local_target_path)
        is_dir = true
        path_size = #local_target_path + 1
    else
        pattern = string.format("^%s$",local_target_path)
        path_size = #local_target_path
    end
    --
    self.IDX = self.IDX + 1
    self.path_tbl[self.IDX] = {
        pattern = pattern,
        cb = cb,
        pkg_path = pkg_path,
        path_size = path_size,
        is_dir = is_dir,


    }
    local watch_id = self.IDX
    self.size = self.size + 1
    self:_check_watch_status()
    return self.IDX
end

function FileWatchMgr:remove_watch(watch_id)
    if self.path_tbl[watch_id] then
        self.size = self.size - 1 
        self.path_tbl[watch_id] = nil
        self:_check_watch_status()
    end
end

function FileWatchMgr:_check_watch_status()
    if self.fw_id then
        if self.size <= 0 then
            self:_set_watch(false)
        end
    else
        if self.size > 0 then
            self:_set_watch(true)
        end
    end
end

function FileWatchMgr:_set_watch(bval)
    if bval then
        self.fw_id = fw.add(self.root_path)
    else
        fw.remove(self.fw_id)
        self.fw_id = nil
    end
end

function FileWatchMgr:update(delta)
    if self.fw_id then
        local typ,path = fw.select()
        if typ then
            local path_unix = string.gsub(path,"\\","/")
            -- log("FileWatchMgr",typ,path)
            local path_tbl = self.path_tbl
            for _,data in pairs(path_tbl) do
                if string.match(path_unix,data.pattern) then
                    if data.is_dir then
                        local ext_path =  string.sub(path_unix,data.path_size+1)
                        local cur_pkg_path = data.pkg_path / ext_path
                        data.cb(typ,cur_pkg_path)
                    else
                        data.cb(typ,data.pkg_path)
                    end
                end
            end
        end
    end
end

local ins
if not ins then
    ins = FileWatchMgr.new()
end

return ins