local util = {}
util.__index = util

function util.create_planeShape(btworld, nx, ny, nz, distance)
	return btworld:new_shape("sphere", nx, ny, nz, distance)
end

function util.create_sphereShape(btworld, radius)
	return btworld:new_shape("sphere", radius)
end

function util.create_capsuleShape(btworld, radius, height, oriaxis)
	return btworld:new_shape("capsule", radius, height, oriaxis)
end

function util.create_compoundShape(btworld)
	return btworld:new_shape("compound")
end

function util.create_cubeShape(btworld, sx, sy, sz)
	return btworld:new_shape("cube", sx, sy, sz)
end

function util.create_shape(btworld, type, arg)
	if type == "plane" then
		return btworld:new_shape(type, arg.nx, arg.ny, arg.nz, arg.distance)
	elseif type == "sphere" then
		return btworld:new_shape(type, arg.radius)
	elseif type == "capsule" then
		return btworld:new_shape(type, arg.radius, arg.height, arg.axis)
	elseif type == "compound" then
		return btworld:new_shape(type)
	elseif type == "cube" then
		return btworld:new_shape(type, arg.sx, arg.sy, arg.sz)
	end
end

return util