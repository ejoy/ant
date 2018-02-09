local ecs = ...

--{@
local math3d = require "math3d"
local math3d_comp = ecs.component "math3d"

function math3d_comp.new()    
	return math3d.new()
end

function math3d_comp:constant(id, value)
	return self(id,value,"MR")
end
--@}

