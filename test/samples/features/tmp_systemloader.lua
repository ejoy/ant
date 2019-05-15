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
ecs.import 'ant.objcontroller'
ecs.import 'ant.math.adapter'

local serialize = import_package 'ant.serialize'

local renderpkg = import_package 'ant.render'
local computil = renderpkg.components
local renderutil=renderpkg.util
local aniutil = import_package 'ant.animation'.util

local ms = import_package 'ant.math'.stack

local lu = renderpkg.light

local PVPScenLoader = require 'PVPSceneLoader'

local init_loader = ecs.system 'init_loader'

init_loader.depend 'timesystem'
init_loader.depend "serialize_index_system"

init_loader.dependby 'render_system'
init_loader.dependby 'primitive_filter_system'
init_loader.dependby 'camera_controller'
init_loader.dependby 'skinning_system'

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
        mesh = {},
        material = {
            content = {
                {
                    ref_path = fs.path "//ant.resources/skin_model_sample.material"
                }
            }
        },
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
                    ref_path = fs.path '//ant.resources' / meshdir / 'animation' / 'animation1.ozz',
                    scale = 1,
                    looptimes = 0,
                    name = 'ani1'
                },
                {
                    ref_path = fs.path '//ant.resources' / meshdir / 'animation' / 'animation2.ozz',
                    scale = 1,
                    looptimes = 0,
                    name = 'ani2'
                }
            },
            blendtype = 'blend'
        },
        skeleton = {
            ref_path = fs.path '//ant.resources' / skepath
        },
        skinning_mesh = {
            ref_path = fs.path '//ant.resources' / smpath
        },
        name = 'animation_sample',
		main_view = true,
		serialize = serialize.create(),
    }

    local e = world[eid]
    local anicomp = e.animation
    aniutil.play_animation(e.animation, anicomp.pose_state.pose)
end

function init_loader:init()
	renderutil.create_render_queue_entity(world, world.args.fb_size, ms({1, 1, -1}, "inT"), {5, 5, -5}, "main_view")
    do
        lu.create_directional_light_entity(world, 'directional_light')
        lu.create_ambient_light_entity(world, 'ambient_light', 'gradient', {1, 1, 1, 1})
    end

    do
        PVPScenLoader.create_entitices(world)
    end

    computil.create_grid_entity(world, 'grid', 64, 64, 1)

    create_animation_test()

	local eid = world:first_entity_id "main_queue"
	local watch = import_package "ant.serialize".watch
	local res1 = watch.query(world, nil, eid.."/camera")
	local res2 = watch.query(world, res1.__id, "")
	watch.set(world, res1.__id, "", "type", "test")
	local res3 = watch.query(world, res1.__id, "")
    
    -- local function save_file(file, data)
    --     assert(assert(io.open(file, 'w')):write(data)):close()
    -- end
    -- -- test serialize world
    -- local s = serialize.save_world(world)
    -- save_file('serialize_world.txt', s)
    -- for _, eid in world:each 'serialize' do
    --     world:remove_entity(eid)
    -- end
    -- serialize.load_world(world, s)

    -- --test serialize entity
    -- local eid = world:first_entity_id 'serialize'
    -- local s = serialize.save_entity(world, eid)
    -- save_file('serialize_entity.txt', s)
    -- world:remove_entity(eid)
    -- serialize.load_entity(world, s)
end
