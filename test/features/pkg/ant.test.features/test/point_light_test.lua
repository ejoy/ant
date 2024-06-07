local ecs   = ...
local world = ecs.world
local w     = world.w

local common    = ecs.require "common"
local iom       = ecs.require "ant.objcontroller|obj_motion"
local util      = ecs.require "util"
local PC        = util.proxy_creator()

local ientity 	= ecs.require "ant.entity|entity"
local imaterial = ecs.require "ant.render|material"
local ilight    = ecs.require "ant.render|light.light"
local math3d    = require "math3d"
local mathpkg   = import_package "ant.math"
local mu, mc    = mathpkg.util, mathpkg.constant

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


local function update_light_prefab(lightprefab, lightinfo, parent)
    local entites = lightprefab.tag['*']
    local root<close> = world:entity(entites[1], "scene:update")
    root.scene.parent = parent
    iom.set_position(root, math3d.vector(lightinfo.pos))

    local sphere<close> = world:entity(entites[4])
    local point<close> = world:entity(entites[5], "light:in")

    imaterial.set_property(sphere, "u_basecolor_factor", lightinfo.color)
    ilight.set_color(point, math3d.tovalue(lightinfo.color))
    ilight.set_range(point, lightinfo.radius)
    ilight.set_intensity(point, ilight.intensity(point) * lightinfo.intensity_scale)
end

local function shadow_plane()
    return PC:create_entity{
		policy = {
			"ant.render|render",
		},
		data = {
			scene 		= {
                t = {0.0, -1.0, 0.0},
				s = {100, 1, 100},
            },
			material 	= "/pkg/ant.resources/materials/mesh_shadow.material",
			mesh		= "plane.primitive",
            visible     = true,
		}
	}

end

local function calc_tangents(ib, vertices)
	local tangents, bitangents = {}, {}

	local function load_vertex(vidx)
		local v = vertices[vidx]
		return {
			p = math3d.vector(v.p),
            n = math3d.vector(v.n),
			u = v.t[1], v = v.t[2],
		}
	end
	--[[
		tangent calculation:
		we have 3 vertices: a, b, c, which have position and uv defined in triangle abc, we make:
			tangent T and bitangent B:
				b.p - a.p = (b.u-a.u)*T + (b.v-a.v)*B
				c.p - a.p = (c.u-a.u)*T + (c.v-a.v)*B
			make:
				ba=b.p-a.p, bau=b.u-a.u, bav=b.v-a.v
				ca=c.p-a.p, cau=c.u-a.u, cav=c.v-a.v

				ba = bau*T + bav*B	==> ba.x = bau*T.x + bav*B.x | ba.y = bau*T.y + bav*B.y | ba.z = bau*T.z + bav*B.z
				ca = cau*T + cav*B	==> ca.x = cau*T.x + cav*B.x | ca.y = cau*T.y + cav*B.y | ca.z = cau*T.z + cav*B.z

				cav*ba = cav*bau*T + cav*bav*B
				bav*ca = bav*cau*T + bav*cav*B

				bav*ca - cav*ba = (bav*cau-cav*bau)*T	==> T = (bav*ca - cav*ba)/(bav*cau - cav*bau)

				let det = (bav*cau-cav*bau), invdet = 1/(bav*cau-cav*bau)
				T = (bav*ca - cav*ba) * invdet

			we can solve T and B
	]]

	local function calc_tangent(vidx0, vidx1, vidx2)
		local a, b, c = load_vertex(vidx0), load_vertex(vidx1), load_vertex(vidx2)

		local ba = math3d.sub(b.p, a.p)
		local ca = math3d.sub(c.p, a.p)
		local bau, bav = b.u - a.u, b.v - a.v
		local cau, cav = c.u - a.u, c.v - a.v

		local det<const> = bau * cav - bav * cau
		local t, bi
		if math3d.ext_util.iszero(det) then
			t, bi = math3d.ext_constant.XAXIS, math3d.ext_constant.ZAXIS
		else
			local invDet<const> = 1.0 / det

			--(ba * cav - ca * bav) * invDet
			--(ca * bau - ba * cau) * invDet
			t, bi = math3d.mul(math3d.sub(math3d.mul(ba, cav), math3d.mul(ca, bav)), invDet),
					math3d.mul(math3d.sub(math3d.mul(ca, bau), math3d.mul(ba, cau)), invDet)
		end

		-- we will merge tangent and bitangent value
		tangents[vidx0]		= tangents[vidx0] and math3d.add(tangents[vidx0], t) or t
		tangents[vidx1]		= tangents[vidx1] and math3d.add(tangents[vidx1], t) or t
		tangents[vidx2]		= tangents[vidx2] and math3d.add(tangents[vidx2], t) or t

		bitangents[vidx0]	= bitangents[vidx0] and math3d.add(bitangents[vidx0], bi) or bi
		bitangents[vidx1]	= bitangents[vidx1] and math3d.add(bitangents[vidx1], bi) or bi
		bitangents[vidx2]	= bitangents[vidx2] and math3d.add(bitangents[vidx2], bi) or bi
	end

    for i=1, #ib, 3 do
        local vidx0, vidx1, vidx2 = ib[i]+1, ib[i+1]+1, ib[i+2]+1
        calc_tangent(vidx0, vidx1, vidx2)
    end

	-- see: http://www.opengl-tutorial.org/intermediate-tutorials/tutorial-13-normal-mapping/#tangent-and-bitangent
	local function make_vector_perpendicular(srcvec, basevec)
		local ndt	= math3d.dot(srcvec, basevec)
		return math3d.sub(srcvec, math3d.mul(basevec, ndt))
	end

	for iv=1, #vertices do
		local tanu 		= tangents[iv]
		local tanv 		= bitangents[iv]
		local normal 	= math3d.vector(vertices[iv].n)
		local tangent	= make_vector_perpendicular(tanu, normal)
		local bitangent	= make_vector_perpendicular(tanv, normal)

		if math3d.ext_util.iszero_math3dvec(tangent) or math3d.ext_util.isnan_math3dvec(tangent) then
			if math3d.ext_util.iszero_math3dvec(bitangent) or math3d.ext_util.isnan_math3dvec(bitangent) then
				tangent = math3d.ext_constant.XAXIS
			else
				tangent = math3d.cross(bitangent, normal)
			end
		end

		tangent	= math3d.normalize(tangent)

		local nxt    	= math3d.cross(normal, tangent)
		tangent	= math3d.set_index(tangent, 4, math3d.dot(nxt, bitangent) < 0 and 1.0 or -1.0)
		vertices[iv].T = math3d.tovalue(tangent)
	end
end

local function pack_tangent_vertices(ib)
    local vertices = {
        --front
        {p = {-0.5,-0.5, 0.5,}, n = {0.0, 0.0, 1.0}, t = {0.0, 1.0}, },
        {p = {-0.5, 0.5, 0.5,}, n = {0.0, 0.0, 1.0}, t = {0.0, 0.0}, },
        {p = {0.5, 0.5, 0.5, }, n = {0.0, 0.0, 1.0}, t = {1.0, 0.0}, },
        {p = {0.5,-0.5, 0.5, }, n = {0.0, 0.0, 1.0}, t = {1.0, 1.0}, },

        --back
        {p = {0.5,-0.5,-0.5, }, n = {0.0, 0.0, -1.0,}, t = {0.0, 1.0},},
        {p = {0.5, 0.5,-0.5, }, n = {0.0, 0.0, -1.0,}, t = {0.0, 0.0},},
        {p = {-0.5, 0.5,-0.5,}, n = {0.0, 0.0, -1.0,}, t = {1.0, 0.0},},
        {p = {-0.5,-0.5,-0.5,}, n = {0.0, 0.0, -1.0,}, t = {1.0, 1.0},},

        --left
        {p={-0.5,-0.5,-0.5,}, n = {-1.0, 0.0, 0.0,}, t = {0.0, 1.0},},
        {p={-0.5, 0.5,-0.5,}, n = {-1.0, 0.0, 0.0,}, t = {0.0, 0.0},},
        {p={-0.5, 0.5, 0.5,}, n = {-1.0, 0.0, 0.0,}, t = {1.0, 0.0},},
        {p={-0.5,-0.5, 0.5,}, n = {-1.0, 0.0, 0.0,}, t = {1.0, 1.0},},

        --right
        {p={0.5,-0.5, 0.5,}, n = {1.0, 0.0, 0.0,}, t = {0.0, 1.0},},
        {p={0.5, 0.5, 0.5,}, n = {1.0, 0.0, 0.0,}, t = {0.0, 0.0},},
        {p={0.5, 0.5,-0.5,}, n = {1.0, 0.0, 0.0,}, t = {1.0, 0.0},},
        {p={0.5,-0.5,-0.5,}, n = {1.0, 0.0, 0.0,}, t = {1.0, 1.0},},

        --top
        {p={-0.5,-0.5,-0.5,}, n = { 0.0,-1.0, 0.0,}, t = {0.0, 1.0},},
        {p={-0.5,-0.5, 0.5,}, n = { 0.0,-1.0, 0.0,}, t = {0.0, 0.0},},
        {p={ 0.5,-0.5, 0.5,}, n = { 0.0,-1.0, 0.0,}, t = {1.0, 0.0},},
        {p={ 0.5,-0.5,-0.5,}, n = { 0.0,-1.0, 0.0,}, t = {1.0, 1.0},},

        --bottom
        {p = { 0.5, 0.5,-0.5,}, n = {0.0, 1.0, 0.0,}, t = {0.0, 1.0},},
        {p = { 0.5, 0.5, 0.5,}, n = {0.0, 1.0, 0.0,}, t = {0.0, 0.0},},
        {p = {-0.5, 0.5, 0.5,}, n = {0.0, 1.0, 0.0,}, t = {1.0, 0.0},},
        {p = {-0.5, 0.5,-0.5,}, n = {0.0, 1.0, 0.0,}, t = {1.0, 1.0},},
    }

    calc_tangents(ib, vertices)

    local t = {}
    for _, v in ipairs(vertices) do
        local Q = math3d.tovalue(mu.pack_tangent_frame(math3d.vector(v.n), math3d.vector(v.T)))
        t[#t+1] = v.p[1]
        t[#t+1] = v.p[2]
        t[#t+1] = v.p[3]

        t[#t+1] = Q[1]
        t[#t+1] = Q[2]
        t[#t+1] = Q[3]
        t[#t+1] = Q[4]

        t[#t+1] = v.t[1]
        t[#t+1] = v.t[2]
    end

    return t
end

local function inside_box()
    local inside_vb = {
        --front
        0.5,-0.5,-0.5, 0.0, 0.0, 1.0,
        0.5, 0.5,-0.5, 0.0, 0.0, 1.0,
        -0.5, 0.5,-0.5, 0.0, 0.0, 1.0,
        -0.5,-0.5,-0.5, 0.0, 0.0, 1.0,
        --back
        -0.5,-0.5, 0.5, 0.0, 0.0,-1.0,
        -0.5, 0.5, 0.5, 0.0, 0.0,-1.0,
        0.5, 0.5, 0.5, 0.0, 0.0,-1.0,
        0.5,-0.5, 0.5, 0.0, 0.0,-1.0,
        --left
        -0.5,-0.5,-0.5, 1.0, 0.0, 0.0,
        -0.5, 0.5,-0.5, 1.0, 0.0, 0.0,
        -0.5, 0.5, 0.5, 1.0, 0.0, 0.0,
        -0.5,-0.5, 0.5, 1.0, 0.0, 0.0,
        --right
        0.5,-0.5, 0.5,-1.0, 0.0, 0.0,
        0.5, 0.5, 0.5,-1.0, 0.0, 0.0,
        0.5, 0.5,-0.5,-1.0, 0.0, 0.0,
        0.5,-0.5,-0.5,-1.0, 0.0, 0.0,
        --bottom
        -0.5,-0.5,-0.5, 0.0, 1.0, 0.0,
        -0.5,-0.5, 0.5, 0.0, 1.0, 0.0,
        0.5,-0.5, 0.5, 0.0, 1.0, 0.0,
        0.5,-0.5,-0.5, 0.0, 1.0, 0.0,
        --top
        0.5, 0.5,-0.5, 0.0,-1.0, 0.0,
        0.5, 0.5, 0.5, 0.0,-1.0, 0.0,
        -0.5, 0.5, 0.5, 0.0,-1.0, 0.0,
        -0.5, 0.5,-0.5, 0.0,-1.0, 0.0,
    }

    local outside_vb = {
        --front
        -0.5,-0.5, 0.5, 0.0, 0.0, 1.0,
        -0.5, 0.5, 0.5, 0.0, 0.0, 1.0,
        0.5, 0.5, 0.5, 0.0, 0.0, 1.0,
        0.5,-0.5, 0.5, 0.0, 0.0, 1.0,

        --back
        0.5,-0.5,-0.5, 0.0, 0.0, -1.0,
        0.5, 0.5,-0.5, 0.0, 0.0, -1.0,
        -0.5, 0.5,-0.5, 0.0, 0.0, -1.0,
        -0.5,-0.5,-0.5, 0.0, 0.0, -1.0,

        --left
        -0.5,-0.5,-0.5,-1.0, 0.0, 0.0,
        -0.5, 0.5,-0.5,-1.0, 0.0, 0.0,
        -0.5, 0.5, 0.5,-1.0, 0.0, 0.0,
        -0.5,-0.5, 0.5,-1.0, 0.0, 0.0,

        --right
        0.5,-0.5, 0.5, 1.0, 0.0, 0.0,
        0.5, 0.5, 0.5, 1.0, 0.0, 0.0,
        0.5, 0.5,-0.5, 1.0, 0.0, 0.0,
        0.5,-0.5,-0.5, 1.0, 0.0, 0.0,

        --top
        -0.5,-0.5,-0.5, 0.0,-1.0, 0.0,
        -0.5,-0.5, 0.5, 0.0,-1.0, 0.0,
         0.5,-0.5, 0.5, 0.0,-1.0, 0.0,
         0.5,-0.5,-0.5, 0.0,-1.0, 0.0,
        --bottom
         0.5, 0.5,-0.5, 0.0, 1.0, 0.0,
         0.5, 0.5, 0.5, 0.0, 1.0, 0.0,
        -0.5, 0.5, 0.5, 0.0, 1.0, 0.0,
        -0.5, 0.5,-0.5, 0.0, 1.0, 0.0,
    }

    local ib = {
         0,  1,  2,  2,  3,  0,
         4,  5,  6,  6,  7,  4,
         8,  9, 10, 10, 11,  8,
        12, 13, 14, 14, 15, 12,
        16, 17, 18, 18, 19, 16,
        20, 21, 22, 22, 23, 20,
    }

    local ppp = {
        --front
        0.5,-0.5,-0.5, 
        0.5, 0.5,-0.5, 
        -0.5, 0.5,-0.5,
        -0.5,-0.5,-0.5,
        --back
        -0.5,-0.5, 0.5,
        -0.5, 0.5, 0.5,
        0.5, 0.5, 0.5, 
        0.5,-0.5, 0.5, 
        --left
        -0.5,-0.5,-0.5, 
        -0.5, 0.5,-0.5, 
        -0.5, 0.5, 0.5, 
        -0.5,-0.5, 0.5, 
        --right
        0.5,-0.5, 0.5,
        0.5, 0.5, 0.5,
        0.5, 0.5,-0.5,
        0.5,-0.5,-0.5,
        --bottom
        -0.5,-0.5,-0.5,
        -0.5,-0.5, 0.5,
        0.5,-0.5, 0.5, 
        0.5,-0.5,-0.5, 
        --top
        0.5, 0.5,-0.5, 
        0.5, 0.5, 0.5, 
        -0.5, 0.5, 0.5,
        -0.5, 0.5,-0.5,
    }

    local pv = pack_tangent_vertices(ib)
    return PC:create_entity{
        policy = {
            "ant.render|simplerender",
        },
        data = {
            scene = {
                t = {0, 0, 0, 1},
                s = 30,
            },
            material    = "/pkg/ant.test.features/assets/test/test.material",
            mesh_result = ientity.create_mesh({"p3|T4|t2", pv,}, ib),
            visible     = true,
        }
    }
end

local function inside_box2()
    return PC:create_entity{
        policy = {
            "ant.render|render",
        },
        data = {
            mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb/meshes/Cube_P1.meshbin",
            material = "/pkg/ant.test.features/assets/test/test2.material",
            visible = true,
            scene = {
                s = 30,
            }
        },
    }
end
w:register{
    name = "rotator",
    type = "float",
}

local function uniform_lights()
    local nx, ny, nz = 8, 8, 8
    local sx, sy, sz = 150, 150, 300
    local dx, dy, dz = sx/nx, sy/ny, sz/nz
    local ox, oy, oz = 24, 0, 0
    local s = 0.5
    dx, dy, dz = dx*s, dy*s, dz*s
    for iz=0, nz-1 do
        local z = iz*dz+oz
        for iy=0, ny-1 do
            local y = iy*dy+oy
            for ix=0, nx-1 do
                local x = ix*dx+ox

                local parent = PC:create_entity{
                    policy = {
                        "ant.scene|scene_object",
                    },
                    data = {
                        scene = {
                            t = {x, y+1, z, 1}
                        },
                        rotator = math.pi * math.random(1, 5) * 0.01,
                    }
                }

                PC:create_instance{
                    prefab = "/pkg/ant.test.features/assets/entities/sphere_with_point_light.prefab",
                    on_ready = function(pl)
                        update_light_prefab(pl, {
                            color   = get_random_color(1),
                            pos     = {0, 0, math.random(3, 10), 1},
                            intensity_scale = math.random(7, 10),
                            radius  = math.random(15, 30),
                        }, parent)
                    end
                }

            end
        end
    end
end

local function Sponza_scene()
    PC:create_instance{
        prefab = "/pkg/ant.test.features/assets/sponza.glb/mesh.prefab",
        on_ready = function (p)
            local root<close> = world:entity(p.tag['*'][1], "scene:update")
            iom.set_scale(root, 10)
        end,
    }

    uniform_lights()
end

local function simple_scene()
    local pl_pos = {
        { pos = {-5, 1, 5,}, radius = 3, intensity_scale=1.0, color=math3d.ref(math3d.vector(1.0, 0.0, 0.0, 1.0))},
        -- { pos = {-5, 1,-5,}, radius = 3, intensity_scale=1.0, color=math3d.ref(math3d.vector(1.0, 0.0, 0.0, 1.0))},
        -- { pos = { 5, 2, 5,}, radius = 3, intensity_scale=1.0, color=math3d.ref(math3d.vector(1.0, 0.0, 0.0, 1.0))},
        -- { pos = { 5, 2,-5,}, radius = 3, intensity_scale=1.0, color=math3d.ref(math3d.vector(1.0, 0.0, 0.0, 1.0))},

        -- { pos = {-10, 1, 10}, radius = 5, intensity_scale=1.0, color=math3d.ref(math3d.vector(0.0, 1.0, 1.0, 1.0))},
        -- { pos = {-10, 1,-10}, radius = 5, intensity_scale=1.0, color=math3d.ref(math3d.vector(0.0, 1.0, 1.0, 1.0))},
        -- { pos = { 10, 2, 10}, radius = 5, intensity_scale=1.0, color=math3d.ref(math3d.vector(0.0, 1.0, 1.0, 1.0))},
        -- { pos = { 10, 2,-10}, radius = 5, intensity_scale=1.0, color=math3d.ref(math3d.vector(0.0, 1.0, 1.0, 1.0))},
        
        -- { pos = {  3, 1, 3}, radius = 10, intensity_scale=1.0},
        -- { pos = { -3, 1, 3}, radius = 10, intensity_scale=1.0},
        -- { pos = {  3, 2,-3}, radius = 10, intensity_scale=1.0},
        -- { pos = {  3, 2,-3}, radius = 10, intensity_scale=1.0},
    }

    local parent = PC:create_entity{
        policy = {
            "ant.scene|scene_object",
        },
        data = {
            scene = {
                t = {1, 3, 1, 1}
            },
            rotator = true,
        }
    }

    for _, p in ipairs(pl_pos) do
        PC:create_instance{
            prefab = "/pkg/ant.test.features/assets/entities/sphere_with_point_light.prefab",
            on_ready = function(pl)
                update_light_prefab(pl, p, parent)
            end
        }
    end

    shadow_plane()

    PC:create_instance {
        prefab = "/pkg/ant.resources.binary/meshes/base/cube.glb/mesh.prefab",
        on_ready = function (ce)
            local root<close> = world:entity(ce.tag['*'][1], "scene:update")
            iom.set_position(root, {0, 0, 0, 1})
        end
    }
end
local function init_camera()
    local mq = w:first "main_queue camera_ref:in"
    local ce<close> = world:entity(mq.camera_ref)
    local eyepos = math3d.vector(0, 10,-10)
    iom.set_position(ce, eyepos)
    iom.set_direction(ce, mc.XAXIS)
end

function plt_sys.init_world()
    init_camera()
    Sponza_scene()
    --simple_scene()
end

function plt_sys.data_changed()
    for e in w:select "rotator:in scene:update" do
        local r = math3d.quaternion{axis=math3d.vector(0.0, 1.0, 0.0, 0.0), r=e.rotator}
        iom.set_rotation(e, math3d.mul(r, iom.get_rotation(e)))
    end
end

local split_frustum = import_package "ant.camera".split_frustum

local setting = import_package "ant.settings"
local CLUSTERSIZE<const> = setting:get "graphic/lighting/cluster_shading/size"

local function test_cluster_aabb()
    local mq = w:first "main_queue render_target:in"
    local irq = ecs.require "ant.render|renderqueue"
    local C = irq.main_camera_entity "camera:in"
    local n, f = C.camera.frustum.n, C.camera.frustum.f
    local vr = mq.render_target.view_rect
    local screensize = {vr.w, vr.h}
    local aabbs = {}
    for iz=1, CLUSTERSIZE[3] do
        for iy=1, CLUSTERSIZE[2] do
            for ix=1, CLUSTERSIZE[1] do
                local id = {ix-1, iy-1, iz-1}
                
                local aabb = split_frustum.build(id, screensize, n, f, math3d.inverse(math3d.projmat(C.camera.frustum)), CLUSTERSIZE)
                aabbs[#aabbs+1] = aabb
                print(("id:[%d, %d, %d], aabb:%s"):format(ix, iy, iz, math3d.tostring(aabb)))
            end
        end
    end

    return aabbs
end

local function test_cluster_light_cull()
    local clustercount = CLUSTERSIZE[1] * CLUSTERSIZE[2] * CLUSTERSIZE[3]
    local aabbs = test_cluster_aabb()
    assert(#aabbs == clustercount)

    local irq = ecs.require "ant.render|renderqueue"
    local C = irq.main_camera_entity "camera:in"
    local viewmat = C.camera.viewmat

    local clusters = {}
    for idx, aabb in ipairs(aabbs) do
        local list = {}
        for e in w:select "scene:in light:in eid:in" do
            local l = {
                pos = math3d.index(e.scene.worldmat, 4),
                range = e.light.range,
            }
            if split_frustum.light_aabb_interset(l, aabb, viewmat) then
                list[#list+1] = e.eid
            end
        end

        clusters[idx] = list
    end

    print ""
end

-- function plt_sys:render_submit()
--     if nil == ONCE then
--         ONCE = true
    
--         test_cluster_light_cull()
--     end
-- end

function plt_sys:exit()
    PC:clear()
end