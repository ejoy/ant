local ecs   = ...
local world = ecs.world
local w     = world.w

local common    = ecs.require "common"
local iom       = ecs.require "ant.objcontroller|obj_motion"
local util      = ecs.require "util"
local PC        = util.proxy_creator()
local imesh     = ecs.require "ant.asset|mesh"
local ientity 	= ecs.require "ant.entity|entity"
local imaterial = ecs.require "ant.render|material"
local ilight    = ecs.require "ant.render|light.light"
local math3d    = require "math3d"
local mu        = import_package "ant.math".util

local plt_sys = common.test_system "point_light"


local function get_color(x, y, z, nx, ny, nz)
    local c1, c2 = math3d.vector(0.3, 0.3, 0.3, 1.0), math3d.vector(0.85, 0.85, 0.85, 1.0)
    --lerp
    local ssx, ssy, ssz = x/nx, y/ny, z/nz
    local t = math3d.vector(ssx, ssy, ssz)
    local nt = math3d.vector(1-ssx, 1-ssy, 1-ssz)
    return math3d.add(math3d.mul(t, c1), math3d.mul(nt, c2))
end

local function get_random_color(colorscale)
    local rr, rg, rb = math.random(), math.random(), math.random()
    local r, g, b = mu.lerp(0.15, 1.0, rr), mu.lerp(0.15, 1.0, rg), mu.lerp(0.15, 1.0, rb)
    return math3d.mul(colorscale, math3d.vector(r, g, b, 1.0))
end


local function update_light_prefab(lightprefab, lightinfo)
    local entites = lightprefab.tag['*']
    local root<close> = world:entity(entites[1], "scene:update")
    iom.set_position(root, lightinfo.pos)

    local sphere<close> = world:entity(entites[4])
    local point<close> = world:entity(entites[5], "light:in")

    imaterial.set_property(sphere, "u_basecolor_factor", lightinfo.color)
    ilight.set_color(point, math3d.tovalue(lightinfo.color))
    ilight.set_range(point, lightinfo.radius)
    ilight.set_intensity(point, ilight.intensity(point) * lightinfo.intensity_scale)
end

local function Sponza_scene()
    PC:create_instance{
        prefab = "/pkg/ant.test.features/assets/sponza.glb/mesh.prefab",
        on_ready = function (p)
            local root<close> = world:entity(p.tag['*'][1], "scene:update")
            iom.set_scale(root, 10)
        end,
    }

    local nx, ny, nz = 8, 8, 8
    local sx, sy, sz = 64, 64, 128
    local dx, dy, dz = sx/nx, sy/ny, sz/nz

    local s = 0.5
    dx, dy, dz = dx*s, dy*s, dz*s
    for iz=0, nz-1 do
        local z = iz*dz
        for iy=0, ny-1 do
            local y = iy*dy
            for ix=0, nx-1 do
                local x = ix*dx

                PC:create_instance{
                    prefab = "/pkg/ant.test.features/assets/entities/sphere_with_point_light.prefab",
                    on_ready = function(pl)
                        update_light_prefab(pl, {
                            color = get_random_color(1),
                            pos = {x, y, z, 1},
                            intensity_scale = 1.0,
                            radius = math.random(3, 5),
                        })
                    end
                }

            end
        end
    end
end

local function simple_scene()
    local pl_pos = {
        { pos = { 1, 1, 1,}, radius = 10, intensity_scale=1.0, color=math3d.ref(math3d.vector(1.0, 0.0, 0.0, 1.0))},
        { pos = {-1, 1,-1,}, radius = 10, intensity_scale=1.0, color=math3d.ref(math3d.vector(1.0, 0.0, 0.0, 1.0))},
        { pos = { 1, 2, 1,}, radius = 10, intensity_scale=1.0, color=math3d.ref(math3d.vector(1.0, 0.0, 0.0, 1.0))},
        { pos = {-1, 2,-1,}, radius = 10, intensity_scale=1.0, color=math3d.ref(math3d.vector(1.0, 0.0, 0.0, 1.0))},

        { pos = {  2, 1, 2}, radius = 10, intensity_scale=1.0, color=math3d.ref(math3d.vector(0.0, 1.0, 1.0, 1.0))},
        { pos = { -2, 1, 2}, radius = 10, intensity_scale=1.0, color=math3d.ref(math3d.vector(0.0, 1.0, 1.0, 1.0))},
        { pos = {  2, 2,-2}, radius = 10, intensity_scale=1.0, color=math3d.ref(math3d.vector(0.0, 1.0, 1.0, 1.0))},
        { pos = {  2, 2,-2}, radius = 10, intensity_scale=1.0, color=math3d.ref(math3d.vector(0.0, 1.0, 1.0, 1.0))},
        
        -- { pos = {  3, 1, 3}, radius = 10, intensity_scale=1.0},
        -- { pos = { -3, 1, 3}, radius = 10, intensity_scale=1.0},
        -- { pos = {  3, 2,-3}, radius = 10, intensity_scale=1.0},
        -- { pos = {  3, 2,-3}, radius = 10, intensity_scale=1.0},
    }

    for _, p in ipairs(pl_pos) do
        PC:create_instance{
            prefab = "/pkg/ant.test.features/assets/entities/sphere_with_point_light.prefab",
            on_ready = function(pl)
                update_light_prefab(pl, p)
            end
        }
    end

    PC:create_entity{
		policy = {
			"ant.render|simplerender",
		},
		data = {
			scene 		= {
				s = {25, 1, 25},
            },
			material 	= "/pkg/ant.resources/materials/mesh_shadow.material",
			mesh_result	= imesh.init_mesh(ientity.plane_mesh()),
            visible     = true,
		}
	}

    PC:create_instance {
        prefab = "/pkg/ant.resources.binary/meshes/base/cube.glb/mesh.prefab",
        on_ready = function (ce)
            local root<close> = world:entity(ce.tag['*'][1], "scene:update")
            iom.set_position(root, {0, 0, 0, 1})
        end
    }
end

function plt_sys.init_world()
    --Sponza_scene()
    simple_scene()
end

local split_frustum = import_package "ant.camera".split_frustum

function plt_sys:render_submit()
    -- if nil == ONCE then
    --     ONCE = true
    
    --     local clustersize = {2, 2, 2}
    --     local mq = w:first "main_queue render_target:in"
    --     local irq = ecs.require "ant.render|renderqueue"
    --     local C = irq.main_camera_entity "camera:in"
    --     local n, f = C.camera.frustum.n, C.camera.frustum.f
    --     local vr = mq.render_target.view_rect
    --     local screensize = {vr.w, vr.h}
    --     local aabbs = {}
    --     for iz=1, clustersize[3] do
    --         for iy=1, clustersize[2] do
    --             for ix=1, clustersize[1] do
    --                 local id = {ix-1, iy-1, iz-1}
                    
    --                 local aabb = split_frustum.build(id, screensize, n, f, math3d.inverse(math3d.projmat(C.camera.frustum)), clustersize)
    --                 aabbs[#aabbs+1] = aabb
    --                 print(("id:[%d, %d, %d], aabb:%s"):format(ix, iy, iz, math3d.tostring(aabb)))
    --             end
    --         end
    --     end

    --     print ""
    -- end
end

function plt_sys:exit()
    PC:clear()
end