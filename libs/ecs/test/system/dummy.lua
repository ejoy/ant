local ecs = ...
local world = ecs.world

--local math3d = require "math3d"

-- local math = ecs.component "math"
-- function math.new()
-- 	return math3d.new()
-- end

local dummy = ecs.system "dummy"

dummy.singleton "init"
--dummy.singleton "math"
dummy.depend "init"
dummy.import "foobar"	-- import foobar methods

function dummy:init()
	print ("Dummy init")
	self:init_print()
	local eid = world:new_entity "foobar"
	--world:add_component(eid, "foobar")
end

function dummy:update()
	print ("Dummy update")
	for _, eid in world:each "foobar" do
		print("1. Dummy foobar", eid)
	end
	world:new_entity "foobar"
	for _, eid in world:each "foobar" do
		print("2. Dummy foobar", eid)
	end
end

function dummy.notify:foobar(set)
	for _, eid in ipairs(set) do
		print ("Notify", eid)
		local e = world[eid]
		if e then
			e:foobar_print()
			--print(self.math(e.foobar.v, "VR"))
			world:remove_entity(eid)
		else
			print ("Notify removed", eid)
		end
	end
end

local dby = ecs.system "dependby"
dby.dependby "dummy"

function dby:init()
	print("in dby:init()")
end