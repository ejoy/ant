package.cpath = "../../bin/?.dll;../../clibs/?.dll"

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

print("Step 1")
w.update()
w.notify()

print("Step 2")
w.update()
w.notify()
