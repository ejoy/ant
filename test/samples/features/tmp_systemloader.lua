local ecs = ...
local world = ecs.world

local fs = require 'filesystem'

ecs.import 'ant.render'
ecs.import 'ant.editor'
ecs.import 'ant.inputmgr'
ecs.import 'ant.serialize'
ecs.import 'ant.scene'
ecs.import 'ant.timer'
ecs.import 'ant.bullet'
ecs.import 'ant.animation'

local renderpkg = import_package 'ant.render'
local computil = renderpkg.components
local aniutil = import_package 'ant.animation'.util

local lu = renderpkg.light

local mathpkg = import_package 'ant.math'
local mathutil = mathpkg.util
local ms = mathpkg.stack

local assetmgr = import_package 'ant.asset'
local PVPScenLoader = require 'PVPSceneLoader'

local serialize = import_package 'ant.serialize'

local init_loader = ecs.system 'init_loader'

init_loader.depend 'shadow_primitive_filter_system'
init_loader.depend 'transparency_filter_system'
init_loader.depend 'entity_rendering'
init_loader.depend 'camera_controller'
init_loader.depend 'skinning_system'
init_loader.depend 'timesystem'

local function create_animation_test()
    local meshdir = fs.path 'meshes'
    local skepath = meshdir / 'skeleton' / 'human_skeleton.ozz'
    local anipaths = {
        meshdir / 'animation' / 'animation1.ozz',
        meshdir / 'animation' / 'animation2.ozz'
    }

    local smpath = meshdir / 'mesh.ozz'

    local anitest_eid =
        world:new_entity(
        'position',
        'scale',
        'rotation',
        'can_render',
        'mesh',
        'material',
        'animation',
        'skeleton',
        'skinning_mesh',
        'name'
    )

    local anitest = world[anitest_eid]
    anitest.name = 'animation_entity'

    mathutil.identify_transform(anitest)
    computil.load_skinning_mesh(anitest.skinning_mesh, anitest.mesh, 'ant.resources', smpath)
    computil.load_skeleton(anitest.skeleton, 'ant.resources', skepath)

    local anicomp = anitest.animation
    aniutil.init_animation(anicomp, anitest.skeleton)
    local anidefine = anicomp.pose.define
    if anidefine.anilist == nil then
        anidefine.anilist = {}
    end
    local weight = 1 / #anipaths
    for idx, anipath in ipairs(anipaths) do
        aniutil.add_animation(anicomp, {package = 'ant.resources', filename = anipath})
        anidefine.anilist[#anidefine.anilist + 1] = {idx = idx, weight = weight}
    end

    aniutil.play_animation(anicomp, anidefine)

    computil.add_material(anitest.material, 'ant.resources', fs.path 'skin_model_sample.material')
end

local function create_hierarchy_test()
    local function create_entity(name, meshfile, materialfile)
        local eid =
            world:new_entity(
            'rotation',
            'position',
            'scale',
            'mesh',
            'material',
            'name',
            'serialize',
            'can_select',
            'can_render'
        )

        local entity = world[eid]
        entity.name = name

        mathutil.identify_transform(entity)

        computil.load_mesh(entity.mesh, meshfile.package, meshfile.filename)
        computil.add_material(entity.material, materialfile.package, materialfile.filename)
        return eid
    end

    local hie_refpath = {package = 'ant.resources', filename = fs.path 'hierarchy' / 'test_hierarchy.hierarchy'}
    do		
		local hierarchy = require 'hierarchy'
		local root = hierarchy.new()

		root[1] = {
			name = 'h1',
			transform = {
				t = {3, 4, 5},
				s = {0.01, 0.01, 0.01}
			}
		}

		root[2] = {
			name = 'h2',
			transform = {
				t = {1, 2, 3},
				s = {0.01, 0.01, 0.01}
			}
		}

		root[1][1] = {
			name = 'h1_h1',
			transform = {
				t = {3, 3, 3},
				s = {0.01, 0.01, 0.01}
			}
		}

		local localfs = require "filesystem.local"

		local function save_rawdata(handle, respath)
			local vfs = require "vfs"
			local fullpath = assetmgr.find_asset_path(respath.package, respath.filename)

			local realpath = vfs.realpath(fullpath:string())
			localfs.create_directories(localfs.path(realpath):parent_path())

			hierarchy.save(handle, realpath)
		end
		
		save_rawdata(root, hie_refpath)
    end

    local hie_materialpath = {package = 'ant.resources', filename = fs.path 'bunny.material'}
    local function create_hierarchy(srt, name)
        local hierarchy_eid =
            world:new_entity(
            'editable_hierarchy',
            'hierarchy_name_mapper',
            'scale',
            'rotation',
            'position',
            'name',
            'serialize'
        )
        local hierarchy_e = world[hierarchy_eid]

        hierarchy_e.name = name

		hierarchy_e.editable_hierarchy.ref_path = hie_refpath
		hierarchy_e.editable_hierarchy.assetinfo = assetmgr.load(hie_refpath.package, hie_refpath.filename)

        ms(hierarchy_e.scale, srt[1], '=')
        ms(hierarchy_e.rotation, srt[2], '=')
		ms(hierarchy_e.position, srt[3], '=')
		
        local entities = {
            h1 = {package = 'ant.resources', filename = fs.path 'cube.mesh'},
            h2 = {package = 'ant.resources', filename = fs.path 'sphere.mesh'},
            h1_h1 = {package = 'ant.resources', filename = fs.path 'cube.mesh'},
        }

        local name_mapper = assert(hierarchy_e.hierarchy_name_mapper)
        for k, v in pairs(entities) do
            local eid = create_entity(k, v, hie_materialpath)
            name_mapper[k] = eid
        end

		local hierarchypkg = import_package 'ant.hierarchy.offline'
		local hieutil = hierarchypkg.util
		hieutil.rebuild_hierarchy(world, hierarchy_eid)
		return hierarchy_eid
    end

	create_hierarchy({
		{1, 1, 1},
		{0, 60, 0},
		{10, 0, 0, 1},		
	}, "hierarchy_test1")

	create_hierarchy({
		{1, 1, 1},
		{0, -60, 0},
		{-10, 0, 0, 1}
	}, "hierarchy_test2")
end

function init_loader:init()
    do
        lu.create_directional_light_entity(world, 'directional_light')
        lu.create_ambient_light_entity(world, 'ambient_light', 'gradient', {1, 1, 1, 1})
    end

    do
        PVPScenLoader.create_entitices(world)
    end

    computil.create_grid_entity(world, 'grid', 64, 64, 1)

	create_animation_test()
	create_hierarchy_test()

    local function save_file(file, data)
        local nativeio = require 'nativeio'
        assert(assert(nativeio.open(file, 'w')):write(data)):close()
    end
    -- test serialize world
    local s = serialize.save_world(world)
    save_file('serialize_world.txt', s)
    for _, eid in world:each 'serialize' do
        world:remove_entity(eid)
    end
    serialize.load_world(world, s)

    -- test serialize entity
    local eid = world:first_entity_id 'serialize'
    local s = serialize.save_entity(world, eid)
    save_file('serialize_entity.txt', s)
    world:remove_entity(eid)
    serialize.load_entity(world, s)
end
