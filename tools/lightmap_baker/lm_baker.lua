local ecs = ...
local world = ecs.world

local ientity = world:interface "ant.render|entity"
local ies = world:interface "ant.scene|ientity_state"
local lm_baker = ecs.system "lightmap_baker_system"

local function create_lm_entity(name, material, m, srt)
    return world:create_entity {
		policy = {
			"ant.render|render",
            "ant.bake|lightmap",
			"ant.general|name",
		},
		data = {
			transform	= srt or {},
			material	= material,
			mesh		= m,
			state		= ies.create_state "visible|lightmap",
            lightmap    = {
                width = 64,
                height = 64,
                channels = 3,
            },
			name		= name,
			scene_entity= true,
		}
	}
end

function lm_baker:init()
    world:instance "/pkg/ant.tool.lightmap_baker/assets/light.prefab"
    world:instance "/pkg/ant.tool.lightmap_baker/assets/skybox.prefab"

    local testmaterial = "/pkg/ant.tool.lightmap_baker/assets/test.material"
    local function create_plane()
        local vb = {
            -1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0xff0000ff, 0.0, 0.0, 0.0, 0.0,
             1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0xff00ffff, 1.0, 0.0, 1.0, 0.0,
             1.0, 0.0,-1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0xffff00ff, 1.0, 1.0, 1.0, 1.0,
            -1.0, 0.0,-1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0xff00ffff, 0.0, 1.0, 0.0, 1.0,
        }

        local ib = {
            0, 1, 2,
            2, 3, 0,
        }

        local mesh = ientity.create_mesh({"p3|n3|T3|c40niu|t20|t21", vb}, ib)
        return create_lm_entity("plane", testmaterial, mesh, {s={10, 1, 10}, t = {0, -3, 0}})
    end

    local function create_box()
        local l, h = 0.333333, 0.5
        local vb = {
            --top
            -1.0, 1.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0xff00008f, 0.0, 0.0, 0.0, 0.0,
             1.0, 1.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0xff00008f, 1.0, 0.0,   l, 0.0,
             1.0, 1.0,-1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0xff00008f, 1.0, 1.0,   l,   h,
            -1.0, 1.0,-1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0xff00008f, 0.0, 1.0, 0.0,   h,

            -- bottom
             1.0,-1.0, 1.0, 0.0,-1.0, 0.0, 1.0, 0.0, 0.0, 0xff00008f, 0.0, 0.0,   l, 0.0,
            -1.0,-1.0, 1.0, 0.0,-1.0, 0.0, 1.0, 0.0, 0.0, 0xff00008f, 1.0, 0.0, 2*l, 0.0,
            -1.0,-1.0,-1.0, 0.0,-1.0, 0.0, 1.0, 0.0, 0.0, 0xff00008f, 1.0, 1.0, 2*l,   h,
             1.0,-1.0,-1.0, 0.0,-1.0, 0.0, 1.0, 0.0, 0.0, 0xff00008f, 0.0, 1.0, 0.0,   h,

            --left
            -1.0, 1.0, 1.0,-1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0xff00008f, 0.0, 0.0, 2*l, 0.0,
            -1.0, 1.0,-1.0,-1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0xff00008f, 1.0, 0.0, 1.0, 0.0,
            -1.0,-1.0,-1.0,-1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0xff00008f, 1.0, 1.0, 1.0,   h,
            -1.0,-1.0, 1.0,-1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0xff00008f, 0.0, 1.0, 0.0,   h,

            --right
             1.0, 1.0,-1.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0xff00008f, 0.0, 0.0, 0.0,   h,
             1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0xff00008f, 1.0, 0.0,   l,   h,
             1.0,-1.0, 1.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0xff00008f, 1.0, 1.0,   l, 1.0,
             1.0,-1.0,-1.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0xff00008f, 0.0, 1.0, 0.0, 1.0,

            --front
            -1.0, 1.0,-1.0, 0.0, 0.0,-1.0, 1.0, 0.0, 0.0, 0xff00008f, 0.0, 0.0,   l,   h,
             1.0, 1.0,-1.0, 0.0, 0.0,-1.0, 1.0, 0.0, 0.0, 0xff00008f, 1.0, 0.0, 2*l,   h,
             1.0,-1.0,-1.0, 0.0, 0.0,-1.0, 1.0, 0.0, 0.0, 0xff00008f, 1.0, 1.0, 2*l, 1.0,
            -1.0,-1.0,-1.0, 0.0, 0.0,-1.0, 1.0, 0.0, 0.0, 0xff00008f, 0.0, 1.0, 0.0, 1.0,

            --back
             1.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0xff00008f, 0.0, 0.0, 2*l,   h,
            -1.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0xff00008f, 1.0, 0.0, 1.0,   h,
            -1.0,-1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0xff00008f, 1.0, 1.0, 1.0, 1.0,
             1.0,-1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0xff00008f, 0.0, 1.0, 0.0, 1.0,
        }

        local ib = {
            --top
            0, 1, 2,
            2, 3, 0,
            --bottom
            4, 5, 6,
            6, 7, 4,
            --left
            8, 9, 10,
            10, 11, 8,
            --right
            12, 13, 14,
            14, 15, 12,
            --front
            16, 17, 18,
            18, 19, 16,
            --back
            20, 21, 22,
            22, 23, 20,
        }

        local mesh = ientity.create_mesh({"p3|n3|T3|c40niu|t20|t21", vb}, ib)
        return create_lm_entity("box", testmaterial, mesh)
    end

    create_plane()
    local eid = create_box()

    world:pub{"bake", eid}
end

function lm_baker:data_changed()

end