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

function filtermesh.dupicate_node(node)
	if node == nil then
		return nil
	end
	assert(type(node) == "table")
	local n = {}
	for k, v in pairs(node) do
		if type(v) == "table" then
			n[k] = filtermesh.dupicate_node(v)
		else
			n[k] = v
		end
	end
	return n
end

local function build_parent_tree(meshscene)
	local tree = {}
	local function build_parent_tree2(scenenodes, parentidx)
		for _, nodeidx in ipairs(scenenodes) do
			local node = meshscene.nodes[nodeidx+1]
			if node.children then
				build_parent_tree2(node.children, nodeidx)
			end
	
			tree[nodeidx] = parentidx
		end
	end
	build_parent_tree2(meshscene.scenes[meshscene.scene+1].nodes)
	return tree
end

local function find_mesh_nodes(meshscene)
	local meshnodes = {}
	for idx1 in ipairs(meshscene.meshes) do
		local meshidx = idx1 - 1
		for idx, node in ipairs(meshscene.nodes) do
			local nodeidx = idx - 1
			if node.mesh == meshidx then
				meshnodes[nodeidx] = true
			end
		end
	end
	return meshnodes
end

local function fetch_nodes_relate_to_mesh(scene, parent_tree)
	local meshnodes = find_mesh_nodes(scene)

	local nodes = {}
	local root_nodes = {}
	local new_old_mapper = {}
	local old_new_mapper = {}

	local function fetch_nodes(nodeidx)
		if old_new_mapper[nodeidx] then
			return
		end

		local new_nodeidx = #nodes
		local node = filtermesh.dupicate_node(scene.nodes[nodeidx+1])
		nodes[#nodes+1] = node
		node.children = nil

		new_old_mapper[new_nodeidx] = nodeidx
		old_new_mapper[nodeidx] = new_nodeidx

		local parent_nodeidx = parent_tree[nodeidx]
		if parent_nodeidx then
			fetch_nodes(parent_nodeidx)
		else
			root_nodes[new_nodeidx] = true
		end
	end

	for nodeidx in pairs(meshnodes) do
		fetch_nodes(nodeidx)
	end

	for idx in ipairs(nodes) do
		local new_nodeidx = idx - 1
		local old_nodeidx = new_old_mapper[new_nodeidx]
		local parent_nodeidx = parent_tree[old_nodeidx]

		if parent_nodeidx then
			local newparent_nodeidx = old_new_mapper[parent_nodeidx]

			local parent_node = nodes[newparent_nodeidx+1]
			local children = parent_node.children
			if children == nil then
				children = {}
				parent_node.children = children
			end
	
			children[#children+1] = new_nodeidx
		end
	end

	local function to_root_nodes()
		local n = {}
		for nodeidx in pairs(root_nodes) do
			n[#n+1] = nodeidx
		end
		table.sort(n, function(l, r) return l < r end)
		return n
	end

	return to_root_nodes(), nodes
end

local function generate_mesh_nodes(scene)
	local meshes = {}
	for _, mesh in ipairs(scene.meshes) do
		meshes[#meshes+1] = filtermesh.dupicate_node(mesh)
	end

	return meshes
end

local function generate_skin_nodes(scene, newscene)
	local skinnodes = {}
	local function add_skin_node(skinidx)
		local newskinidx = #skinnodes
		skinnodes[#skinnodes+1] = filtermesh.dupicate_node(scene.skins[skinidx+1])
		return newskinidx
	end
	for _, node in ipairs(newscene.nodes) do
		if node.skin then
			node.skin = add_skin_node(node.skin)
		end
	end
	return next(skinnodes) and skinnodes or nil
end

local function generate_accessors(scene, newscene)
	local new_accessors = {}
	local function add_accessor(accidx)
		local newaccidx = #new_accessors
		new_accessors[#new_accessors+1] = filtermesh.dupicate_node(scene.accessors[accidx+1])
		return newaccidx
	end
	for _, node in ipairs(newscene.nodes) do
		local meshidx = node.mesh
		if meshidx then
			local meshnode = newscene.meshes[meshidx+1]
			for _, prim in ipairs(meshnode.primitives) do
				if prim.indices then
					prim.indices = add_accessor(prim.indices)
				end

				for k, v in pairs(prim.attributes) do
					prim.attributes[k] = add_accessor(v)
				end
			end
		end
	end

	if newscene.skins then
		for _, skin in ipairs(newscene.skins) do
			skin.inverseBindMatrices = add_accessor(skin.inverseBindMatrices)
		end
	end

	return new_accessors
end

local function generate_bufferViews(scene, newscene)
	local new_bufferViews = {}
	local function add_bufferView(bvidx)
		local newbvidx = #new_bufferViews
		new_bufferViews[#new_bufferViews+1] = filtermesh.dupicate_node(scene.bufferViews[bvidx+1])
		return newbvidx
	end
	for _, acc in ipairs(newscene.accessors) do
		acc.bufferView = add_bufferView(acc.bufferView)
	end

	return new_bufferViews
end

local function generate_buffers(scene, newscene, bin)
	local buffercontent = {}
	local startoffset = 0
	for _, bv in ipairs(newscene.bufferViews) do
		bv.buffer = 0
		local startbytes = bv.byteOffset + 1
		local endbytes = startbytes + bv.byteLength - 1
		buffercontent[#buffercontent+1] = bin:sub(startbytes, endbytes)

		bv.byteOffset = startoffset
		startoffset = startoffset + bv.byteLength
	end

	local newbin = table.concat(buffercontent)

	assert(#scene.buffers == 1)
	return {
		byteLength = #newbin
	}, newbin
end

function filtermesh.filter_scene(scene, bin)
	local parent_tree 			= build_parent_tree(scene)
	local rootnodes, newnodes 	= fetch_nodes_relate_to_mesh(scene, parent_tree)

	assert(scene.scene == 0)
	local newscene = {
		scene = 0,
		scenes = {
			{nodes = rootnodes},
		},
		scenelods = filtermesh.dupicate_node(scene.scenelods),
		nodes = newnodes,
		meshes = generate_mesh_nodes(scene),
	}

	newscene.skins = generate_skin_nodes(scene, newscene)
	newscene.accessors = generate_accessors(scene, newscene)
	newscene.bufferViews = generate_bufferViews(scene, newscene)
	local newbin
	newscene.buffers, newbin  = generate_buffers(scene, newscene, bin)
	return newscene, newbin
end

function filtermesh.extract_colider_mesh(scene)

end

return filtermesh