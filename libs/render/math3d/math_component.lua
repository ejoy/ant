local ecs = ...

--{@
local math3d = require "math3d"
local math3d_comp = ecs.component "math_stack"

function math3d_comp.new()    
	return math3d.new()
end

function math3d_comp:constant(id, value)
	return self(id,value,"MR")
end

function math3d_comp:lookat(is_persistent)
end

function math3d_comp:perspective(is_persistent)
end

function math3d_comp:ortho(is_persistent)
end

function math3d_comp:vector(is_persistent)
end

function math3d_comp:quat(is_persistent)
end

function math3d_comp:euler(is_persistent)
end

function math3d_comp:matrix(is_persistent)
end

--@}

