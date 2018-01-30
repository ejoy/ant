local ecs = ...
local world = ecs.world

local init = ecs.component "init" -- single object

function init.new()
	-- return singleton object
	return {
		foobar = ""
	}
end

function init:print()
	print(self.foobar)
end

local init_system = ecs.system "init"

init_system.singleton "init"	-- depend singleton components

function init_system:init()
	print ("Init system")
	self.init.foobar = "Hello"
end

function init_system:update()
	print "Init update"
end
