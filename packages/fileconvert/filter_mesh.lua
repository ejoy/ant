local filtermesh = {}; filtermesh.__index = filtermesh

local lodmatch_pattern = ".+_[Ll][Oo][Dd]%d%d?"

local function find_lod(scene, nodelist, parentindices)
	for _, nodeidx in ipairs(nodelist)do
		local node = scene.nodes[nodeidx+1]

		local name = node.name
		if name:match(lodmatch_pattern) then
			assert(#parentindices==0)
			table.insert(parentindices, 1, nodeidx)
			return nodeidx
		end

		if node.children then
			local foundidx = find_lod(node.children, nodeidx)
			if foundidx then
				table.insert(parentindices, 1, nodeidx)
			end
			return foundidx
		end
	end
end

local function copy_list(from)
	if from then
		local to = {}
		for idx, v in ipairs(from) do
			to[idx] = v
		end
		return to
	end
end

function filtermesh.spiltlod(scene)
	local parentindices = {}
	local sceneidx = scene.scene
	local nodeidx = find_lod(scene, scene.scenes[sceneidx+1].nodes, parentindices)

	if nodeidx then
		local lodparent_idx = parentindices[-1]
		local parentnode = scene.nodes[lodparent_idx+1]
		local scenelods = {}

		for _, lodidx in ipairs(parentnode.children)do
			local lodnode = scene.nodes[lodidx+1]
			if lodnode.name:match(lodmatch_pattern) then
				local childidx = lodidx
				for idx=#parentindices, 1, -1 do
					local oldnode = parentindices[idx+1]
					scene.nodes[#scene.nodes+1] = {
						matrix		= copy_list(oldnode.matrix),
						translation = copy_list(oldnode.translation),
						rotation 	= copy_list(oldnode.rotation),
						scale 		= copy_list(oldnode.scale),
						children 	= {childidx},
					}

					childidx = #scene.nodes
				end

				scenelods[#scenelods+1] = childidx
				scene.scenes[#scene.scenes+1] = {nodes={childidx}}
			end
		end

		scene.scenelods = scenelods
		scene.scene = scenelods[1]	-- point to lod0 scene
	end
end

function filtermesh.extract_colider_mesh(scene)

end

return filtermesh