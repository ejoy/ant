local ecs = ...

ecs.import "ant.inputmgr"

local oc_sys = ecs.system "objcontroller_system"
oc_sys.singleton "message"
oc_sys.require_system "message_system"

local objcontroller = require "objcontroller"

function oc_sys:init()	
	objcontroller.init(self.message)
end

function oc_sys:update()
	objcontroller.update()
end