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

	local tm_mb = world:sub {"test_mark"}

	local dummy = ecs.system "dummy"

	dummy.singleton "init"
	dummy.require_system "init"

	local fp = ecs.policy "foobar"
	fp.require_component "foobar"
	fp.require_component "name"
	fp.require_system "dummy"

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

		world:pub {"test_mark", eid}
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

		world:pub {"test_mark2", newid, "test arg111"}
		print("Create foobar", newid)
		for _, eid in world:each "foobar" do
			print("2. Dummy foobar", eid)
		end
	end

	local handle_sys = ecs.system "handle_system"
	function handle_sys:update()
		for msg in tm_mb:each() do
			local eid = msg[2]
			local arg = msg[3]
			local e = world[eid]
			if e then
				print("[dummy], eid:", eid, arg)
			else
				print("[dummy], eid:", eid, "has been removed")
			end
		end
	end

	local dby = ecs.system "dependby"
	dby.require_system "dummy"

	function dby:init()
		print("in dby:init()")
	end

	local new_foobar_event = world:sub {"component_register", "foobar"}
	
	local newdummy = ecs.system "new"

	local tm1_mb = world:sub {"test_mark"}
	local tm2_mb = world:sub {"test_mark2"}

	function newdummy:update()
		for msg in new_foobar_event:each() do
			local eid = msg[3]
			print("New foobar", eid)
			world:remove_entity(eid)
		end

		for msg in tm1_mb:each() do
			local eid = msg[2]
			if world[eid] then
				print("test_mark:", eid, world[eid].name or "[..]")
			else
				print("test_mark:", eid, "has been removed")
			end
		end

		for msg in tm2_mb:each() do
			local eid = msg[2]
			if world[eid] then
				print("test_mark2:", eid, world[eid].name or "[..]")
			else
				print("test_mark2:", eid, "has been removed")
			end
		end
	end

	local delete = ecs.system "delete"

	local remove_foobar = world:sub {"component_removed", "foobar"}

	function delete:delete()
		for _, cname, eid, e in remove_foobar:unpack() do
			local c = e[cname]
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
