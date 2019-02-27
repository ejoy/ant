local ecs = ...
local world = ecs.world

ecs.component "foobar"
	.x "real"
	.y "real"

local foobar = ecs.component "foobar"

local test = ecs.system "test_event"

test.singleton "event"

function test:init()
	world:create_entity {
		foobar = { x = 1, y = 2 },
	}
end

function test:post_init()
	for eid in world:each_new "foobar" do
		print("New entity", eid)
		self.event:new(eid, "foobar")
	end
end

function test:update()
	for _, eid in world:each "foobar" do
		local e = world[eid]
		local watcher_foobar = e.foobar.watcher
		watcher_foobar.x = 0
		watcher_foobar.y = 0
	end
	for eid, modify in self.event:each "foobar" do
		local foobar = world[eid].foobar
		print("Old", eid, foobar.x, foobar.y)
		print("Modify", eid, modify.x, modify.y)
	end
end

