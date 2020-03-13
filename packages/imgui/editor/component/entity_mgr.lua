local MgrBase = require "mgr_base"
local gui_input = require "gui_input"
local gui_util = require "editor.gui_util"

local hub = import_package("ant.editor").hub
local Event = require "hub_event"

local EntityMgr = MgrBase.derive("EntityMgr")

EntityMgr.MgrName = "EntityMgr"
function EntityMgr:_init()
    MgrBase._init(self)
    self:_init_subcribe()
end

function EntityMgr:_init_subcribe()

end

--{parent=,policy=,data=,str=}
function EntityMgr:request_new_entity(arg)
    hub.publish(Event.ETR.NewEntity,arg)
end

function EntityMgr:request_duplicate_entity(eids)
    hub.publish(Event.ETR.DuplicateEntity,eids)
end

return EntityMgr