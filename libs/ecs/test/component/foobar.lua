local ecs = ...

local foobar = ecs.component "foobar" {
	x = 0.0,
	y = 0.0,
	v = { type = "vector" }
}

function foobar:init()
	print("New component foobar")
	self.temp = 0
end

function foobar:print()
	print(self.x, self.y, self.temp)
end