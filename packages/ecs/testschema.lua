local schema = require "schema"

local p = schema.new()

p:type "NAME"
	["temp"].a "int" (1)
	.b "OBJECT"
	[ "private" ].c "id" (0)
--	.d "texture"
	.array "int[4]" { 1,2,3,4 }
	.any "var" (nil)
	.map "int{}" { x = 1, y = 2 }

p:typedef("id" , "int", 1)
p:primtype "OBJECT"
p:check()

