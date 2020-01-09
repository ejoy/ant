local ecs = ...

local oc_sys = ecs.system "objcontroller_system"

local objcontroller = require "objcontroller"

function oc_sys:init()	
	objcontroller.init() -- TODO
end

function oc_sys:update()
	objcontroller.update()
end
