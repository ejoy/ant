local util = {}; util.__index = util

local ms = import_package "ant.math".stack

local function load_world_trans(ske, idx, worldpos)
	local srt = worldpos[idx]
	if srt == nil then
		local function build_hierarchy_indices(idx)
			local indices = {}
			local curidx = idx
			while not ske:isroot(curidx) do
				table.insert(indices, curidx)
				curidx = ske:parent(curidx)
			end
			assert(ske:isroot(curidx))
			table.insert(indices, curidx)
			return indices				
		end

		local indices = build_hierarchy_indices(idx)

		local function get_matrix(i)
			local ii = indices[i]				
			local fsrt = worldpos[ii]
			if fsrt then
				return fsrt, true
			end
			return ms:matrix(ske:joint_matrix(ii)), false
		end

		local num_indices = #indices
		
		srt = get_matrix(num_indices)
		for i=num_indices-1, 1, -1 do
			local csrt, isworld = get_matrix(i)
			if isworld then
				srt = csrt
			else
				srt = ms(srt, csrt, "*P")
			end
		end
	
		worldpos[idx] = srt
	end
	
	return srt
end

function util.generate_joints_worldpos(ske)
	local worldpos = {}
	for i=1, #ske do
		load_world_trans(ske, i, worldpos)
	end	

	return worldpos
end

return util