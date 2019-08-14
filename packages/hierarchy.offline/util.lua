local util = {}
util.__index = util

local hierarchy_module = require 'hierarchy'
local fs = require 'filesystem'
local lfs = require 'filesystem.local'

local math = import_package 'ant.math'
local ms = math.stack
local assetmgr = import_package 'ant.asset'

local function create_hierarchy_path(ref_path)
    local ext = ref_path:extension()
    assert(ext == fs.path '.hierarchy')
    local newfilename = ref_path:string():gsub('%.hierarchy$', '-hie.hierarchy')
    return fs.path(newfilename)
end

--[@	find editable_hierarchy reference path
local function add_hierarchy_component(world, eid, ref_path)
    local e = world[eid]
    if e.hierarchy == nil then
        world:add_component(eid, 'hierarchy', {
			ref_path = create_hierarchy_path(ref_path)
		})
    end
end

local function mark_refpath(erefpath, refpath, moditied_files)
    local content = moditied_files[erefpath]
    if content == nil then
        moditied_files[erefpath] = refpath
    end
end

local function find_hie_entity(world, eid, moditied_files)
    local e = world[eid]
    local mapper = e.hierarchy_name_mapper
    if mapper then
        local erefpath = e.editable_hierarchy.ref_path

        add_hierarchy_component(world, eid, erefpath)
        mark_refpath(erefpath, e.hierarchy.ref_path, moditied_files)

        for _, eid in pairs(mapper) do
            find_hie_entity(world, eid, moditied_files)
        end
    end
end

local function save_rawdata(handle, respath)
	local realpath = respath:localpath()
	lfs.create_directories(realpath:parent_path())

	handle:save(realpath:string())
end

local function update_transform(world, pe, psrt)
	local mapper = pe.hierarchy_name_mapper
	if mapper then
		local hiecomp = pe.hierarchy
        local refpath = hiecomp.ref_path
        local hieres = assetmgr.get_resource(refpath)
        if hieres == nil then
            hieres = assetmgr.load(refpath)
        end
		
		for _, node in ipairs(hieres.handle) do
			local rot = ms(ms:quaternion(node.r), 'eP')
			local csrt = ms(psrt, ms:srtmat(node.s, rot, node.t), '*P')
			local s, r, t = ms(csrt, '~PPP')
			local ceid = mapper[node.name]
			local ce = world[ceid]
			local srt = ce.transform
			ms(srt.t, t, '=', 
				srt.r, r, '=',
				srt.s, s, '=')
			update_transform(world, ce, csrt)
		end
	end
end

function util.rebuild_hierarchy(world, eid_rebuild)
    local moditied_files = {}
    find_hie_entity(world, eid_rebuild, moditied_files)
	local rootentity = world[eid_rebuild]

    for epath, rpath in pairs(moditied_files) do
        local root = assetmgr.load(epath)

        -- we need to rewrite the file from cache
        if assetmgr.has_res(epath) then
            save_rawdata(root.handle, epath)
        end

        local builddata = hierarchy_module.build(root.handle)
		save_rawdata(builddata, rpath)
    end

	local rootsrt = ms:srtmat(rootentity.transform)
    update_transform(world, rootentity, rootsrt)
end

return util
