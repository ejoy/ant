local ecs = ...
local world = ecs.world
local schema = ecs.schema

schema:type "foobar"
	.x "real"
	.y "real"

local foobar = ecs.component "foobar"

local test = ecs.system "test_modify"

test.singleton "modify"

function test:init()
	world:create_entity {
		foobar = { x = 1, y = 2 },
	}
end

function test:post_init()
	for eid in world:each_new "foobar" do
		print("New entity", eid)
		self.modify:new(eid, "foobar")
	end
end

function test:update()
	for _, eid in world:each "foobar" do
		local e = world[eid]
		local modify_foobar = e.foobar.modify
		modify_foobar.x = 0
		modify_foobar.y = 0
	end
	for eid, modify in self.modify:each "foobar" do
		local foobar = world[eid].foobar
		print("Old", eid, foobar.x, foobar.y)
		print("Modify", eid, modify.x, modify.y)
	end
end

