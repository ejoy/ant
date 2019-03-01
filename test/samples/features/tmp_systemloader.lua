local ecs = ...
local world = ecs.world

local fs = require 'filesystem'

ecs.import 'ant.basic_components'
ecs.import 'ant.render'
ecs.import 'ant.editor'
ecs.import 'ant.inputmgr'
ecs.import 'ant.serialize'
ecs.import 'ant.scene'
ecs.import 'ant.timer'
ecs.import 'ant.bullet'
ecs.import 'ant.animation'
ecs.import 'ant.event'

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
	
	local anilist = {}		
	for _, anipath in ipairs(anipaths) do
		anilist[#anilist+1] ={ref_path = anipath}
	end

	local eid = world:create_entity {
		transform = {			
				s = {1, 1, 1, 0},
				r = {0, 0, 0, 0},
				t = {0, 0, 0, 1},
		},
		can_render = true,
		mesh = {},
		material = {
			content = {
				{
					ref_path = {package = 'ant.resources', filename = fs.path 'skin_model_sample.material'}
				}
			}
		},
		animation = {
			pose_state = {
				pose = {
					anirefs = {
						{idx = 1, weight = 0.5},
						{idx = 2, weight = 0.5},
					}
				}
			},
			anilist = {
				{
					ref_path = {package = "ant.resources", filename = meshdir / 'animation' / 'animation1.ozz'},
					scale = 1,
					looptimes = 0,
					name = "ani1",
				},
				{
					ref_path = {package= "ant.resources", filename = meshdir / 'animation' / 'animation2.ozz'},
					scale = 1,
					looptimes = 0,
					name = "ani2",
				}
			},
			blendtype = "blend",
		},
		skeleton = {
			ref_path = {package = "ant.resources", filename = skepath},
		},
		skinning_mesh = {
			ref_path = {package = "ant.resources", filename = smpath},
		},
		name = "animation_sample",
		main_viewtag = true,
	}

	local e = world[eid]
	local anicomp = e.animation
    aniutil.play_animation(e.animation, anicomp.pose_state.pose)
end

local function create_hierarchy_test()
    local function create_entity(name, meshfile, materialfile)
        return world:create_entity {
				transform = {
					s = {1, 1, 1, 0},
					r = {0, 0, 0, 0},
					t = {0, 0, 0, 1},
				},
				mesh = {
					ref_path = meshfile,
				},
				material = {
					content = {
						{
							ref_path = materialfile,
						}
					}
				},
				name = name,
				serialize = import_package 'ant.serialize'.create(), 
				can_select = true,
				can_render = true,
				main_viewtag = true,
			}
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
			local fullpath = assetmgr.find_asset_path(respath.package, respath.filename)

			local realpath = fullpath:localpath()
			localfs.create_directories(realpath:parent_path())

			hierarchy.save(handle, realpath:string())
		end
		
		save_rawdata(root, hie_refpath)
    end

    local hie_materialpath = {package = 'ant.resources', filename = fs.path 'bunny.material'}
	local function create_hierarchy(srt, name)


        local hierarchy_eid = world:create_entity {
			editable_hierarchy = {
				ref_path = hie_refpath,
			},
			hierarchy_name_mapper = {},
			transform = {				
				s = srt[1],
				r = srt[2],
				t = srt[3],				
			},
			name = name,
			serialize = import_package 'ant.serialize'.create(), 
		}

		local hentity = world[hierarchy_eid]
		local name_mapper = hentity.hierarchy_name_mapper
		for k, v in pairs {
			h1 = 'cube.mesh',
			h2 = 'sphere.mesh',
			h1_h1 ='cube.mesh',
		} do
			name_mapper[k] = create_entity(k, {package = 'ant.resources', filename = fs.path(v)}, hie_materialpath)
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

local function check_hierarchy_name_mapper()
	for _, eid in world:each("hierarchy") do
		local e = world[eid]
		if e.serialize then
			local hiemapper = e.hierarchy_name_mapper
			if hiemapper then
				assert(next(hiemapper))
				for k, ceid in pairs(hiemapper) do
					print("slot name:", k, "child name:", world[ceid].name)
				end
			end
		end
	end
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
    --local eid = world:first_entity_id 'serialize'
    --local s = serialize.save_entity(world, eid)
    --save_file('serialize_entity.txt', s)
    --world:remove_entity(eid)
	--serialize.load_entity(world, s)

	check_hierarchy_name_mapper()
end
