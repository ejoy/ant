local filtermesh = {}; filtermesh.__index = filtermesh

local lodmatch_pattern = ".+_[Ll][Oo][Dd](%d+)"

local function find_lod(scene, nodelist, parentindices)
	for _, nodeidx in ipairs(nodelist)do
		local node = scene.nodes[nodeidx+1]

		local name = node.name
		if name:match(lodmatch_pattern) then
			assert(#parentindices==0)
			return nodeidx
		end

		if node.children then
			local foundidx = find_lod(scene, node.children, parentindices)
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

local function scene_lod(scene, idx)
	local s = scene.scenes[idx+1]
	local lodlevel = s.name:match "[^:]+:(%d+)"
	return tonumber(assert(lodlevel))
end

local function select_lod(scene, lodidx)
	local scenelods = scene.scenelods
	if lodidx == nil then
		return scenelods[1]
	end

	for _, idx in ipairs(scenelods)do
		if scene_lod(scene, idx) == (lodidx - 1) then
			return idx
		end
	end
end

function filtermesh.spiltlod(scene, lodidx)
	local parentindices = {}
	local sceneidx = scene.scene
	local nodeidx = find_lod(scene, scene.scenes[sceneidx+1].nodes, parentindices)

	if nodeidx then
		local lodparent_idx = parentindices[#parentindices]
		local parentnode = scene.nodes[lodparent_idx+1]
		local scenelods = {}

		for _, lodidx in ipairs(parentnode.children)do
			local lodnode = scene.nodes[lodidx+1]
			local lodlevel = lodnode.name:match(lodmatch_pattern)
			if lodlevel then
				local childidx = lodidx
				for parentidx=#parentindices, 1, -1 do
					local nodeidx = parentindices[parentidx]
					local node = scene.nodes[nodeidx+1]
					assert(node.mesh == nil )
					scene.nodes[#scene.nodes+1] = {
						matrix		= copy_list(node.matrix),
						translation = copy_list(node.translation),
						rotation 	= copy_list(node.rotation),
						scale 		= copy_list(node.scale),
						children 	= {childidx},
					}

					childidx = #scene.nodes - 1	-- -1 for rebase index, make it start from 0
					assert(childidx >= 0)
				end

				scene.scenes[#scene.scenes+1] = {name="LOD root scene:" .. lodlevel, nodes={childidx}}
				scenelods[#scenelods+1] = #scene.scenes - 1	-- -1 for rebase index, make it start from 0
			end
		end

		scene.scenelods = scenelods
		table.sort(scenelods, function (idx0, idx1) return scene_lod(scene, idx0) < scene_lod(scene, idx1) end)
		scene.scene = select_lod(scene, lodidx)
	end
end

function filtermesh.extract_colider_mesh(scene)

end

return filtermesh