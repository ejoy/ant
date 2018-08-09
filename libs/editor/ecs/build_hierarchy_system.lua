local ecs = ...
local world = ecs.world

local hierarchy_module = require "hierarchy"
local hu = require "scene.hierarchy.util"
local path = require "filesystem.path"

local build_system = ecs.system "build_hierarchy_system"
build_system.singleton "math_stack"

local mu = require "math.util"

local assetmgr = require "asset"

local function mark_modified_file(filepath, content, modified_files)
	local assetdir = assetmgr.assetdir()
	filepath = path.join(assetdir, filepath)

	local c = modified_files[filepath]	
	if c == nil then		
		path.create_dirs(filepath)
		modified_files[filepath] = content
	else
		--assert(c == content)
	end
end

local function create_hierarchy_path(ref_path)	
	local ext = path.ext(ref_path)
	assert(ext:lower() == "hierarchy")
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
				build(ms, ceid, modified_files)
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

local function build_hierarchy_update_tree(eid, branch, tree, modified_files)
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

			build_hierarchy_update_tree(ceid, branch.children, tree, modified_files)
		end
	end
end

local function rebuild_hierarchy(ms, iterop)	
	local moditied_files = {}

	--[@	find editable_hierarchy reference path
	local function add_hierarchy_component(eid, ref_path)
		local e = world[eid]
		local hie = e.hierarchy
		if hie == nil then
			world:add_component(eid, "hierarchy")
			hie = e.hierarchy
			hie.ref_path = create_hierarchy_path(ref_path)
		end	
	end	

	local function mark_refpath(erefpath, refpath)		
		local content = moditied_files[erefpath]
		if content == nil then
			moditied_files[erefpath] = refpath
		end
	end

	for _, eid in iterop() do
		local function find_hie_entity(eid)
			local e = world[eid]
			local hm = e.hierarchy_name_mapper
			if hm then
				local erefpath = e.editable_hierarchy.ref_path				
				add_hierarchy_component(eid, erefpath)
				mark_refpath(erefpath, e.hierarchy.ref_path)

				local mapper = hm.v
				for _, eid in pairs(mapper) do
					find_hie_entity(eid)										
				end
			end
		end

		find_hie_entity(eid)
	end
	--@]

	--[@	use hierarchy path to save refercene resource
	for epath, rpath in pairs(moditied_files) do		
		-- load the cache if it has been loaded(this cache will be modified by program), otherwise load it from file
		local hascache = assetmgr.has_res(epath)
		local root = assetmgr.load(epath, {editable=true})
		-- we need to rewrite the file from cache
		local assetdir = assetmgr.assetdir()
		if hascache then
			local assetpath = path.join(assetdir, epath)
			path.create_dirs(assetpath)
			hierarchy_module.save(root, assetpath)
		end

		local builddata = hierarchy_module.build(root)
		local pp = path.join(assetdir, rpath)
		path.create_dirs(pp)
		hierarchy_module.save(builddata, pp)
	end
	--[@

	
	--[@	use the new updated resource to update entity srt
	for _, eid in iterop() do
		local e = world[eid]
		local rootsrt = mu.srt_from_entity(ms, e)

		local function update_transform(pe, psrt)
			local hm = pe.hierarchy_name_mapper
			if hm then
				local mapper = hm.v
				local builddata = assetmgr.load(pe.hierarchy.ref_path)
				pe.hierarchy.builddata = builddata
				local srt = psrt
				for _, node in ipairs(builddata) do
					local rot = ms({type="q", table.unpack(node.r)}, "eP")
					local csrt = ms({type="srt", s=node.s, r=rot, t=node.t}, srt, "*P")
					local s, r, t = ms(csrt, "~PPP")
					local ceid = mapper[node.name]
					local ce = world[ceid]
					ms(ce.position.v, t, "=")
					ms(ce.rotation.v, r, "=")
					ms(ce.scale.v, s, "=")
					update_transform(ce, csrt)
				end			
			end
		end

		update_transform(e, rootsrt)
	end
	--@]
end

function build_system:init()
	rebuild_hierarchy(self.math_stack, function ()
		return world:each("editable_hierarchy") end)
end

function build_system.notify:rebuild_hierarchy(set)
	rebuild_hierarchy(self.math_stack, function () return ipairs(set) end)
end