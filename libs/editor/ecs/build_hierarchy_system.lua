local ecs = ...
local world = ecs.world

local hierarchy_module = require "hierarchy"
local hu = require "scene.hierarchy.util"
local path = require "filesystem.path"

local build_system = ecs.system "build_hierarchy_system"
build_system.singleton "math_stack"

local assetmgr = require "asset"

local function mark_modified_file(filepath, content, modified_files)
	local assetdir = assetmgr.assetdir()
	filepath = path.join(assetdir, filepath)

	local c = modified_files[filepath]	
	if c == nil then		
		path.create_dirs(filepath)
		modified_files[filepath] = content
	else
		assert(c == content)
	end
end

local function create_hierarchy_path(ref_path)	
	assert(path.ext(ref_path):lower() == "hierarchy")
	ref_path = path.remove_ext(ref_path)
	ref_path = ref_path .. "-hie.hierarchy"	
	return ref_path
end

local function build(ms, eid, modified_files)
	local e = world[eid]
	local ehierarchy = e.editable_hierarchy
	if ehierarchy then
		local hierarchy = e.hierarchy
		if hierarchy == nil then
			world:add_component(eid, "hierarchy")
			hierarchy = e.hierarchy
			hierarchy.ref_path = create_hierarchy_path(ehierarchy.ref_path)
		end

		local root = assert(ehierarchy.root)
		local builddata = assert(hierarchy_module.build(root))
		hierarchy.builddata = builddata
		hu.update_hierarchy_entiy(ms, world, e)

		mark_modified_file(ehierarchy.ref_path, root, modified_files)
		mark_modified_file(hierarchy.ref_path, builddata, modified_files)
		
		local hie_np = e.hierarchy_name_mapper
		if hie_np then
			local namemapper = hie_np.v
			for _, ceid in pairs(namemapper) do
				build(ms, ceid)
			end
		end
	end
end

local function is_eid_in_tree(eid, tree)
	if tree == nil or next(tree) == nil then
		return false
	end

	for _, ceid in ipairs(tree) do
		if ceid == eid then
			return true
		end
	end

	return is_eid_in_tree(eid, tree.children)
end

local function build_hierarchy_update_tree(eid, branch, tree)
	if is_eid_in_tree(eid, tree) then
		return 
	end

	local e = world[eid]
	local hie_np = e.hierarchy_name_mapper
	if hie_np then
		local mapper = hie_np.v
		table.insert(branch, eid)
		
		for _, ceid in pairs(mapper) do
			if branch.children == nil then
				branch.children = {}
			end

			build_hierarchy_update_tree(ceid, branch.children, tree)
		end
	end
end

local function rebuild_hierarchy(ms, iterop)
	local tree = {}
	for _, eid in iterop() do
		build_hierarchy_update_tree(eid, tree, tree)
	end

	-- only first node, child node in build function will be called
	local modified_files = {}
	for _, eid in ipairs(tree) do
		build(ms, eid, modified_files)
	end

	for filepath, content in pairs(modified_files) do
		hierarchy_module.save(content, filepath)
	end
end

function build_system:init()
	rebuild_hierarchy(self.math_stack, function ()
		return world:each("editable_hierarchy") end)
end

function build_system.notify:rebuild_hierarchy(set)
	rebuild_hierarchy(self.math_stack, function () return ipairs(set) end)
end