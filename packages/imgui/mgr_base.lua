local class     = require "common.class"
local MgrBase   = class("MgrBase")
local dbgutil = import_package "ant.editor".debugutil

--mgr have frame_update,setting(opt),and mainmenu(opt)

MgrBase.MgrName = "MgrBase"

function MgrBase:_init()

end

--return ret,status
function MgrBase:try(fun,...)
    return dbgutil.try(fun,...)
end

function MgrBase:on_update(delta)
    
end

--override if needed
function MgrBase:get_mainmenu()
    self.get_mainmenu = false
end

function MgrBase.get_ins(MyClass)
    local gui_mgr = require "gui_mgr"
    local ins = gui_mgr.getMgr(MyClass.MgrName)
    return ins
end


----------------custom_setting----------------

--override if needed
--return tbl
function MgrBase:save_setting_to_memory(clear_dirty_flag)
    
end

--override if needed
function MgrBase:load_setting_from_memory(seting_tbl)
    self.load_setting_from_memory = false
end

--override if needed
function MgrBase:is_setting_dirty()
    return false
end

----------------custom_setting----------------

return MgrBase