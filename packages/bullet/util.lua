local ms = import_package "ant.math".stack

local util = {}; util.__index = util

function util.fill_collider_info(collidercomp, boundings)
	local collider = collidercomp.collider
	local shapeinfo = collidercomp.shape

	local shapetype = shapeinfo.type
	local aabb = boundings.aabb

	local function vec_sub(a, b)
		return ms(a, b, "-T")
	end

	local function vec_add(a, b)
		return ms(a, b, "+T")
	end

	local size = vec_sub(aabb.max, aabb.min)

	if shapetype == "box" then
		shapeinfo.size = size
	elseif shapetype == "sphere" then		
		shapeinfo.radius = math.max(size[1], math.max(size[2], size[3]))
	elseif shapetype == "plane" then
		shapeinfo.normal = {0, 1, 0}
		shapeinfo.distance = -size[2]
	elseif shapetype == "capsule" or shapetype == "cylinder" then 
		shapeinfo.radius = math.min(size[1], math.min(size[2], size[3]))
		shapeinfo.height = math.max(size[1], math.max(size[2], size[3]))
		
		local axis = 1
		for i=2, 3 do
			local nextaxis = axis+1
			if size[nextaxis] > size[axis] then
				axis = nextaxis
			end
		end
		shapeinfo.axis = axis
	else
		assert(false, string.format("not support type:%s", shapetype))
	end
	
	collider.center = vec_add(aabb.max, aabb.min)	
end

function util.create_collider_comp(btworld, shape, collider, transform)	
	local pos = ms(transform.t, collider.center, "+P")
	
	assert(collider.handle == nil)
	collider.handle = btworld:create_collider(assert(shape.handle), collider.obj_idx, pos, ms(transform.r, "qP"))
end

function util.create_collider(btworld, shapehandle, obj_idx, pos, rot)
	local object = btworld:new_obj(shapehandle, obj_idx, pos, rot)
	btworld:add_obj(object)
	return object
end

return util