-- test solve_depend

TEST = true
log = {}
function log.info(name)
	local tag = "[" .. name .. "] "
	local write = io.write
	return function(fmt, ...)
		write(tag)
		write(string.format(fmt, ...))
		write("\n")
	end
end


local system = require "system"

local test = {
	a = { depend = { "b", "c" } },
	b = { depend = { "c" } },
	c = {},
	d = { depend = { "b", "a" } },
}

local list = system._solve_depend(test)
assert(table.concat(list) == "cbad")

-- test ecs

local ecs = require "ecs"

local mods = {}

function mods.basetype(...)
	local ecs = ...

	ecs.component_base("int", 0)
	ecs.component_base("real", 0.0)
	ecs.component_base("string", "")
	ecs.component_base("boolean", false)
end

function mods.dummy(...)
	local ecs = ...
	local world = ecs.world

	ecs.component_alias("name", "string")

	ecs.mark("test_mark", "mark_handler")
	ecs.mark("test_mark2", "mark_handler2")

	local dummy = ecs.system "dummy"

	dummy.singleton "init"
	dummy.depend "init"

	local fp = ecs.policy "foobar"
	fp.require_component "foobar"
	fp.require_component "name"

	function dummy:init()
		print ("Dummy init")
		local eid = world:create_entity {
			policy = {
				"foobar"
			},
			data = {
				foobar = {
					x = 0, y = 0,
				},
				name = "foobar_name"
			}
		}

		world:mark(eid, "test_mark")
	end

	function dummy:update()
		print ("Dummy update")
		for _, eid in world:each "foobar" do
			print("1. Dummy foobar", eid)
		end
		local newid = world:create_entity {
			policy = {
				"foobar",
			},
			data = {
				foobar = {
					x = 1, y = 1,
				},
				name = "foobar_name2",
			}
		}

		world:mark(newid, "test_mark2", "test arg111")
		print("Create foobar", newid)
		for _, eid in world:each "foobar" do
			print("2. Dummy foobar", eid)
		end
	end

	function dummy:mark_handler()
		print("handle 'mark_handler', list number:")
		for eid, arg in world:each_mark "test_mark2" do
			local e = world[eid]
			if e then
				print("[dummy], eid:", eid, arg)
			else
				print("[dummy], eid:", eid, "has been removed")
			end
		end
	end

	local dby = ecs.system "dependby"
	dby.dependby "dummy"

	function dby:init()
		print("in dby:init()")
	end

	local new_foobar_event = world:sub {"foobar"}
	
	local newdummy = ecs.system "new"

	function newdummy:update()
		for msg in new_foobar_event:each() do
			local eid = msg[2]
			print("New foobar", eid)
			world:remove_entity(eid)
		end
	end

	function newdummy:mark_handler()
		print("handle 'mark_handler'")
		for eid in world:each_mark "test_mark" do
			if world[eid] then
				print("test_mark:", eid, world[eid].name or "[..]")
			else
				print("test_mark:", eid, "has been removed")
			end
		end
	end

	function newdummy:mark_handler2()
		print("handle 'mark_handler2'")
		for eid in world:each_mark "test_mark2" do
			if world[eid] then
				print("test_mark2:", eid, world[eid].name or "[..]")
			else
				print("test_mark2:", eid, "has been removed")
			end
		end
	end

	local delete = ecs.system "delete"

	function delete:delete()
		for eid, info in world:each_removed "foobar" do
			local c = info[1]
			local e = info[2]
			print("Delete foobar", eid, "foobar", c.x, c.y, "name:", e.name or "")
		end
	end
end

function mods.init(...)
	local ecs = ...

	local init = ecs.singleton "init"
	local init_system = ecs.system "init"

	init_system.singleton "init"	-- depend singleton components

	function init_system:init()
		print ("Init system")
		self.init.foobar = "Hello"
	end

	function init_system:update()
		print "Init update"
	end
end

function mods.foobar(...)
	local ecs = ...

	local foobar = ecs.component "foobar"
		.x "real"
		.y "real"

	function foobar:init()
		print("New component foobar")
		self.temp = 0
		return self
	end

	function foobar:delete()
		print("Delete", self.x, self.y)
	end

end

local w = ecs.new_world {
	packages = { "basetype", "dummy", "init", "foobar" },
	systems = { "init", "dummy", "new", "delete" },
	loader = function(name) return mods[name] end,
	update_order = { "init" },
}

w:enable_system("dummy", true)

local init = w:update_func "init"
init()
local update = w:update_func "update"
local delete = w:update_func "delete"

local function update_all()
	update()
	w:update_marks()
	w:clear_all_marks()
	delete()
	w:clear_removed()
end

print("Step 1")
update_all()

w:enable_system("dummy", true)

print("Step 2")
update_all()

print("disable dummy system")
w:enable_system("dummy", false)

print("Step 3")
update_all()
