--luacheck: ignore self

local ecs = ...
local world = ecs.world

local hierarchy_module = require "hierarchy"
local fs = require "filesystem"

local math = import_package "math"
local ms = math.stack
local mu = math.util
local assetmgr = require "asset"


local build_system = ecs.system "build_hierarchy_system"

local function create_hierarchy_path(ref_path)	
	local ext = ref_path:extension()
	assert(ext == fs.path ".hierarchy")	
	local newfilename = ref_path:string():gsub("%.hierarchy$", "-hie.hierarchy")	
	return fs.path(newfilename)
end

local function rebuild_hierarchy(iterop)
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
		local content = moditied_files[erefpath:string()]
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
		if hascache then			
			fs.create_directories(epath:parent_path())
			hierarchy_module.save(root, epath:string())
		end

		local builddata = hierarchy_module.build(root)		
		fs.create_directories(rpath:parent_path())
		hierarchy_module.save(builddata, rpath:string())
	end
	--[@

	
	--[@	use the new updated resource to update entity srt
	for _, eid in iterop() do
		local e = world[eid]
		local rootsrt = mu.srt_from_entity(e)

		local function update_transform(pe, psrt)
			local mapper = pe.hierarchy_name_mapper
			if mapper then				
				local builddata = assetmgr.load(pe.hierarchy.ref_path)
				pe.hierarchy.builddata = builddata				
				for _, node in ipairs(builddata) do
					local rot = ms({type="q", table.unpack(node.r)}, "eP")
					local csrt = ms(psrt, {type="srt", s=node.s, r=rot, t=node.t}, "*P")
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
	rebuild_hierarchy(function ()
		return world:each("editable_hierarchy") end)
end

function build_system.notify:rebuild_hierarchy(set)
	rebuild_hierarchy(function () return ipairs(set) end)
end