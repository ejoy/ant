local math3d = require "math3d"

local stack = math3d.new()

local cmdlist = {
	cmdidx = 1
}

cmdlist.__index = cmdlist

function cmdlist:push_cmd(...)
	local num = select('#', ...)
	for i=1, num do
		local c = select(i, ...)
		if c then
			local i = self.cmdidx
			self[i] = c
			self.cmdidx = i + 1
		end
	end	
end

function cmdlist:reindex()
	self.cmdidx = 1
end

function cmdlist:reset()
	self:reindex()
	for i=#self, 1, -1 do
		self[i] = nil
	end
end

function cmdlist:list()
	return table.unpack(self, 1, self.cmdidx - 1)
end


local mymath = {}
mymath.__index = mymath

function mymath:mul(f1, f2)
	cmdlist:push_cmd(f1, f2, "*")
	return self
end

function mymath:mulH(f1, f2)
	cmdlist:push_cmd(f1, f2, "%")
	return self
end

function mymath:add(f1, f2)
	cmdlist:push_cmd(f1, f2, "+")
	return self
end

function mymath:sub(f1, f2)
	cmdlist:push_cmd(f1, f2, "-")
	return self
end

function mymath:dot(f1, f2)
	cmdlist:push_cmd(f1, f2, ".")
	return self
end

function mymath:cross(f1, f2)
	cmdlist:push_cmd(f1, f2, "*")
	return self
end

function mymath:normalize(f1)
	cmdlist:push_cmd(f1, "n")
	return self
end

function mymath:decompose_mat(f1)
	cmdlist:push_cmd(f1, "~")
	return self
end

function mymath:rotation_to_axis(f1)
	cmdlist:push_cmd(f1, "b")
	return self
end

function mymath:lookat(eye, at, direction)
	cmdlist:push_cmd(assert(eye), assert(at), direction and "L" or "l")
	return self
end

function mymath:perspective_FovAspect(fov, aspect)
	cmdlist:push_cmd({type = "mat", fov=fov, aspect=aspect})
	return self
end

function mymath:perspective_t(t)
	cmdlist:push_cmd(t)
	return self
end

function mymath:perspective(l, r, t, b, n, f)
	cmdlist:push_cmd({type="mat", l=l, r=r, t=t, b=b, n=n, f=f})
	return self
end

function mymath:ortho(l, r, t, b, n, f)
	cmdlist:push_cmd({type="mat", l=l, r=r, t=t, b=b, n=n, f=f, ortho=true})
	return self
end

function mymath:assign(lhs, rhs)
	assert(type(lhs) == "userdata")
	cmdlist:push_cmd(lhs, rhs, "=")
	return self
end

function mymath:to_forward(f1)
	cmdlist:push_cmd(f1, "d")
	return self
end

function mymath:to_rotation(f1)
	cmdlist:push_cmd(f1, "D")
	return self
end

function mymath:to_quaternion(f1)
	cmdlist:push_cmd(f1, "q")
	return self
end

function mymath:to_euler(f1)
	cmdlist:push_cmd(f1, "e")
	return self
end

function mymath:duplicate(idx)
	cmdlist:push_cmd(tostring(idx))
	return self
end

function mymath:swap()
	cmdlist:push_cmd("S")
	return self
end

function mymath:remove()
	cmdlist:push_cmd("R")
	return self
end

function mymath:push(...)
	cmdlist:push_cmd(...)
	return self
end

function mymath:pop()
	return self:tostack("P")
end

function mymath:new_vec_ref()
	return math3d.ref "vector"
end

function mymath:new_mat_ref()
	return math3d.ref "matrix"
end

function mymath:tostack(c)
	cmdlist:push_cmd(c)	
	local r = stack(cmdlist:list())
	cmdlist:list()
	return r
end

function mymath:topointer()
	return self:tostack("m")
end

function mymath:totable()
	return self:tostack("T")
end

function mymath:tostring()
	return self:tostack("V")
end

function mymath:toresult()
	return self:tostack("P")
end

function mymath:reset()
	cmdlist:reset()
	math3d.reset(stack)
end

return mymath