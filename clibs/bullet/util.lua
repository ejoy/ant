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

return util