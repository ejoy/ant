local resource = require "resource"

local code = {}

local function make_resource(name, func)
	code[name] = string.dump(func)
end

local function loader(ext, filename, data)
	print("Load", filename)
	local func = load(data)
	return func()
end

make_resource("a.code", function() return { a = 1, b = 2, c = 3 } end)

resource.register(loader, function(tbl, filename) print("Unload", filename) end)

local function reload_code(name)
	resource.reload(name, code[name])
end

local function load_code(name, lazyload)
	resource.load(name, code[name], lazyload)
end

local proxy = resource.proxy "a.code"

assert(resource.status(proxy) == "ref")
assert(tostring(proxy) == "a.code")

local result = {}
resource.status(proxy, result)
assert(result[1] == "a.code")

reload_code "a.code"

assert(proxy.a == 1)
assert(proxy.b == 2)
assert(proxy.c == 3)

make_resource("a.code", function()
	return {
		x = { 1,2,3 },
		y = { a = { b = { "hello" } } },
		z = {
			{ "hello" },
			{ "world" },
		},
		a = { x = 1 },
		b = { y = 2 },
	}
end)

reload_code "a.code"	-- reload

local touched = resource.monitor("a.code", true)

assert(touched() == false)

assert(resource._data == nil)	-- invalid

assert(touched() == false)

assert(proxy.x[1] == 1)

assert(touched() == true)

resource.monitor("a.code", false)	-- turn off monitor

resource.unload "a.code"

load_code "a.code"
resource.unload "a.code"
load_code ("a.code", true)	-- turn on autoload

resource.unload "a.code"

local clone = resource.patch(proxy,
	{
			z =  {
				{ "hello_patched" },
			},
	}
)

assert(clone.x[1] == 1)
assert(clone.z[1][1] == "hello_patched")
print(clone.z[2][1]	== "world")
