local schema = require "schema"

local p = schema.new()

p:type "NAME"
	["temp"].a "int" (1)
	.b "OBJECT"
	[ "private" ].c "id" (0)
--	.d "texture"
	.array "int[4]" { 1,2,3,4,5 }

p:typedef("id" , "int", 1)
p:userdata "OBJECT"
p:check()

