package.cpath = "../../clibs/?.dll;../../bin/?.dll"
--package.path = "./?.lua;../?.lua;../?/?.lua"

--[@ hack vfs.fs
local fs = {}
function fs.isfile(filepath)
	local f, err = io.open(filepath, "r")
	if f then
		return true
	end
	print(err)
	return false
end
package.loaded["vfs.fs"] = fs
--@]

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
--local modules = require "module"

--local m = modules "test/system;test/component"
local module_searchdirs = "./?.lua"
local w = ecs.new_world { modules = {
				"test.system.dummy", 
				"test.system.init", 
				"test.component.foobar" }, 
				module_path = module_searchdirs, update_order = { "init" } }

w.enable_system("dummy", true)

print("Step 1")
w.update()
w.notify()

w.enable_system("dummy", true)

print("Step 2")
w.update()
w.notify()

print("disable dummy system")
w.enable_system("dummy", false)

print("Step 3")
w.update()
w.notify()
