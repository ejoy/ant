--luacheck: ignore self

local ecs = ...
local world = ecs.world

local hierarchy_module = require "hierarchy"
local fs = require "filesystem"
local localfs = require "filesystem.local"
local vfs = require "vfs"

local math = import_package "ant.math"
local ms = math.stack
local mu = math.util
local assetmgr = import_package "ant.asset"


local build_system = ecs.system "build_hierarchy_system"

local function create_hierarchy_path(ref_respath)	
	local ext = ref_respath:extension()
	assert(ext == fs.path ".hierarchy")	
	local newfilename = ref_respath:string():gsub("%.hierarchy$", "-hie.hierarchy")	
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
			hie.ref_path = {ref_path[1], create_hierarchy_path(ref_path[2])}
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

	local function save_rawdata(data, pkgname, respath)
		local fullpath = assetmgr.find_asset_path(pkgname, respath)

		local realpath = vfs.realpath(fullpath:string())
		localfs.create_directories(localfs.path(realpath):parent_path())

		hierarchy_module.save(data, realpath)
	end

	--[@	use hierarchy path to save refercene resource
	for epath, rpath in pairs(moditied_files) do		
		-- load the cache if it has been loaded(this cache will be modified by program), otherwise load it from file
		local pkgname, hpath = rpath[1], rpath[2]

		local epkgname, ehpath = epath[1], epath[2]
		local root = assetmgr.load(epkgname, ehpath, {editable=true})

		-- we need to rewrite the file from cache		
		if assetmgr.has_res(epkgname, ehpath) then
			save_rawdata(root, epkgname, ehpath)
		end

		local builddata = hierarchy_module.build(root)		
		save_rawdata(builddata, pkgname, hpath)
	end
	--[@

	
	--[@	use the new updated resource to update entity srt
	for _, eid in iterop() do
		local e = world[eid]
		local rootsrt = mu.srt_from_entity(e)

		local function update_transform(pe, psrt)
			local mapper = pe.hierarchy_name_mapper
			if mapper then				
				local hie = pe.hierarchy
				local refpath = hie.ref_path
				local builddata = assetmgr.load(refpath[1], refpath[2])
				hie.builddata = builddata
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