local ecs = ...
local world = ecs.world

ecs.import "render.math3d.math_component"

local hierarchy_module = require "hierarchy"
local path = require "filesystem.path"

local build_system = ecs.system "build_hierarchy_system"
build_system.singleton "math_stack"

local mu = require "math.util"

local assetmgr = require "asset"

local function create_hierarchy_path(ref_path)	
	local ext = path.ext(ref_path)
	assert(ext:lower() == "hierarchy")
	ref_path = path.remove_ext(ref_path)
	ref_path = ref_path .. "-hie.hierarchy"	
	return ref_path
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
			local mapper = e.hierarchy_name_mapper
			if mapper then
				local erefpath = e.editable_hierarchy.ref_path				
				add_hierarchy_component(eid, erefpath)
				mark_refpath(erefpath, e.hierarchy.ref_path)

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
			path.create_dirs(path.parent(assetpath))
			hierarchy_module.save(root, assetpath)
		end

		local builddata = hierarchy_module.build(root)
		local pp = path.join(assetdir, rpath)
		path.create_dirs(path.parent(pp))
		hierarchy_module.save(builddata, pp)
	end
	--[@

	
	--[@	use the new updated resource to update entity srt
	for _, eid in iterop() do
		local e = world[eid]
		local rootsrt = mu.srt_from_entity(ms, e)

		local function update_transform(pe, psrt)
			local mapper = pe.hierarchy_name_mapper
			if mapper then				
				local builddata = assetmgr.load(pe.hierarchy.ref_path)
				pe.hierarchy.builddata = builddata
				local srt = psrt
				for _, node in ipairs(builddata) do
					local rot = ms({type="q", table.unpack(node.r)}, "eP")
					local csrt = ms({type="srt", s=node.s, r=rot, t=node.t}, srt, "*P")
					local s, r, t = ms(csrt, "~PPP")
					local ceid = mapper[node.name]
					local ce = world[ceid]
					ms(ce.position, t, "=")
					ms(ce.rotation, r, "=")
					ms(ce.scale, s, "=")
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