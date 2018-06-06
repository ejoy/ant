package.cpath = "../../clibs/?.dll;../../bin/?.dll"

function log(name)
	local tag = "[" .. name .. "] "
	local write = io.write
	return function(fmt, ...)
		write(tag)
		write(string.format(fmt, ...))
		write("\n")
	end
end

-- test solve_depend

TEST = true

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
local modules = require "module"

local m = modules "test/system;test/component"

local w = ecs.new_world { modules = m , update_order = { "init" } }

w.enable_system("dummy", false)

print("Step 1")
w.update()
w.notify()

w.enable_system("dummy", true)

print("Step 2")
w.update()
w.notify()
