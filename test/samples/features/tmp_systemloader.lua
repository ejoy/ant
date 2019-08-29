local ecs = ...
local world = ecs.world

local fs = require 'filesystem'


ecs.import 'ant.basic_components'
ecs.import 'ant.math.adapter'
ecs.import 'ant.asset'
ecs.import 'ant.render'
ecs.import 'ant.editor'
ecs.import 'ant.inputmgr'
ecs.import 'ant.serialize'
ecs.import 'ant.scene'
ecs.import 'ant.timer'
ecs.import 'ant.bullet'
ecs.import 'ant.animation'
ecs.import 'ant.event'
ecs.import 'ant.objcontroller'


local serialize = import_package 'ant.serialize'

local renderpkg = import_package 'ant.render'
local computil  = renderpkg.components
local aniutil   = import_package 'ant.animation'.util

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util

local lu = renderpkg.light

local PVPScenLoader = require 'PVPSceneLoader'

local init_loader = ecs.system 'init_loader'
init_loader.singleton "asyn_load_list"

init_loader.depend 'timesystem'
init_loader.depend "serialize_index_system"

init_loader.dependby 'render_system'
init_loader.dependby 'cull_system'
init_loader.dependby 'primitive_filter_system'
init_loader.dependby 'camera_controller'
init_loader.dependby 'skinning_system'
init_loader.dependby 'viewport_detect_system'

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
        anilist[#anilist + 1] = {ref_path = anipath}
    end

    local eid =
        world:create_entity {
        transform = {
            s = {1, 1, 1, 0},
            r = {0, 0, 0, 0},
            t = {0, 2, 0, 1}
        },
        can_render = true,
        rendermesh = {},
        material = computil.assign_material(fs.path "/pkg/ant.resources/materials/skin_model_sample.material"),
        animation = {
            pose_state = {
                pose = {
                    anirefs = {
                        {idx = 1, weight = 0.5},
                        {idx = 2, weight = 0.5}
					},
					name = "walk",
                }
            },
            anilist = {
                {
                    ref_path = fs.path '/pkg/ant.resources' / meshdir / 'animation' / 'animation1.ozz',
                    scale = 1,
                    looptimes = 0,
                    name = 'ani1'
                },
                {
                    ref_path = fs.path '/pkg/ant.resources' / meshdir / 'animation' / 'animation2.ozz',
                    scale = 1,
                    looptimes = 0,
                    name = 'ani2'
                }
            },
            blendtype = 'blend'
        },
        skeleton = {
            ref_path = fs.path '/pkg/ant.resources' / skepath
        },
        skinning_mesh = {
            ref_path = fs.path '/pkg/ant.resources' / smpath
        },
        name = 'animation_sample',
		main_view = true,
		serialize = serialize.create(),
    }

    local e = world[eid]
    local anicomp = e.animation
    aniutil.play_animation(e.animation, anicomp.pose_state.pose)
end

local function test_serialize(delfile_aftertest)
	--local eid = world:first_entity_id "main_queue"
	--local watch = import_package "ant.serialize".watch
	--local res1 = watch.query(world, nil, eid.."/camera")
	--local res2 = watch.query(world, res1.__id, "")
	--watch.set(world, res1.__id, "", "type", "test")
	--local res3 = watch.query(world, res1.__id, "")
    
    local function save_file(file, data)
        assert(assert(io.open(file, 'w')):write(data)):close()
    end
    -- test serialize world
    local s = serialize.save_world(world)
    save_file('serialize_world.txt', s)
    for _, eid in world:each 'serialize' do
        world:remove_entity(eid)
    end
    world:update_func "delete"()
    world:clear_removed()
    serialize.load_world(world, s)
    -- DO NOT call update_func "init", if you donot close the world
    -- in this test, just call "post_init" is enougth
    world:update_func "post_init"()

    --test serialize entity
    local eid = world:first_entity_id 'serialize'
    local s = serialize.save_entity(world, eid)
    save_file('serialize_entity.txt', s)
    world:remove_entity(eid)
    serialize.load_entity(world, s)

    if delfile_aftertest then
        local lfs = require "filesystem.local"
        lfs.remove(lfs.path 'serialize_world.txt')
        lfs.remove(lfs.path 'serialize_entity.txt')
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

    computil.create_grid_entity(world, 'grid', 64, 64, 1, nil, mu.translate_mat {0, 0, 0})
    create_animation_test()
end

function init_loader:asset_loaded()
    -- local ll = self.asyn_load_list
    -- -- scene finish
    -- if ll.i >= ll.n then
    --     if  not __ANT_RUNTIME__ and 
    --         not _RUN_TEST_SERIALIZE_ then
    --         test_serialize(true)
    --         _RUN_TEST_SERIALIZE_ = true
    --     end
    -- end
end
