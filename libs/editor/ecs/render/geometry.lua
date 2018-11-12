local geometry = {}; geometry.__index = geometry

function geometry.box_from_aabb(aabb, needib, line)
	local function create_vb()
		if aabb then
			local min, max = aabb.min, aabb.max

			local maxx, maxy, maxz = max[1], max[2], max[3]
			local minx, miny, minz = min[1], min[2], min[3]
			return {
					min,
					{minx, maxy, minz},	-- ltn
					{maxx, maxy, minz},	-- rtn
					{maxx, miny, minz},	-- rbn
		
					{maxx, miny, maxz},	-- rbf
					max,
					{minx, maxy, maxz},	-- ltf
					{minx, miny, maxz},	-- lbf			
				}
		end
	end

	local function line_ib()
		if needib then
			if line then
				return {
					0, 1,
					1, 2,
					2, 3,
					3, 0,
			
					4, 5,
					5, 6,
					6, 7,
					7, 4,
			
					0, 7,
					1, 6,
					2, 5,		
					3, 4,
				}
			else
				assert(false)
				return nil
			end
		end
	end	
	return create_vb(), line_ib()
end

return geometry