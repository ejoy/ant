local util = {}; util.__index = util


function util.create_ctrl_wrapper(create_op, mt)
	local c = create_op()
	assert(type(c) == "userdata")
	local owner = setmetatable({view=c}, mt)
	c.owner = owner
	return owner
end

return util