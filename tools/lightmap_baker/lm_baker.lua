local ecs = ...
local world = ecs.world

local ientity = world:interface "ant.render|entity"

local lm_baker = ecs.system "lightmap_baker_system"

local function create_lm_entity(name, material, m, srt)
    return world:create_entity {
		policy = {
			"ant.render|render",
			"ant.general|name",
		},
		data = {
			transform	= srt or {},
			material	= material,
			mesh		= m,
			state		= ies.create_state "visible|lightmap",
			name		= name,
			scene_entity= true,
		}
	}
end

function lm_baker:init()
    local testmaterial = "/pkg/ant.tool.lightmap_baker/assets/test.material"
    local function create_plane()
        local vb = {
            -1.0, 0.0, 1.0, 0xff0000ff, 0.0, 0.0, 0.0, 0.0,
             1.0, 0.0, 1.0, 0xff00ffff, 1.0, 0.0, 1.0, 0.0,
             1.0, 0.0,-1.0, 0xffff00ff, 1.0, 1.0, 1.0, 1.0,
            -1.0, 0.0,-1.0, 0xff00ffff, 0.0, 1.0, 0.0, 1.0,
        }

        local ib = {
            0, 1, 2,
            2, 3, 1,
        }

        local mesh = ientity.create_mesh({"p3|c40nui|t20|t21", vb}, ib)
        return create_lm_entity("plane", testmaterial, mesh)
    end

    local function create_box()
        local l, h = 0.333333, 0.5
        local vb = {
            --top
            -1.0, 1.0, 1.0, 0xff00008f, 0.0, 0.0, 0.0, 0.0,
             1.0, 1.0, 1.0, 0xff00008f, 1.0, 0.0,   l, 0.0,
             1.0, 1.0,-1.0, 0xff00008f, 1.0, 1.0,   l,   h,
            -1.0, 1.0,-1.0, 0xff00008f, 0.0, 1.0, 0.0,   h,

            -- bottom
             1.0,-1.0, 1.0, 0xff00008f, 0.0, 0.0,   l, 0.0,
            -1.0,-1.0, 1.0, 0xff00008f, 1.0, 0.0, 2*l, 0.0,
            -1.0,-1.0,-1.0, 0xff00008f, 1.0, 1.0, 2*l,   h,
             1.0,-1.0,-1.0, 0xff00008f, 0.0, 1.0, 0.0,   h,

            --left
            -1.0, 1.0, 1.0, 0xff00008f, 0.0, 0.0, 2*l, 0.0,
            -1.0, 1.0,-1.0, 0xff00008f, 1.0, 0.0, 1.0, 0.0,
            -1.0,-1.0,-1.0, 0xff00008f, 1.0, 1.0, 1.0,   h,
            -1.0,-1.0, 1.0, 0xff00008f, 0.0, 1.0, 0.0,   h,

            --right
             1.0, 1.0,-1.0, 0xff00008f, 0.0, 0.0, 0.0,   h,
             1.0, 1.0, 1.0, 0xff00008f, 1.0, 0.0,   l,   h,
             1.0,-1.0, 1.0, 0xff00008f, 1.0, 1.0,   l, 1.0,
             1.0,-1.0,-1.0, 0xff00008f, 0.0, 1.0, 0.0, 1.0,

            --front
            -1.0, 1.0,-1.0, 0xff00008f, 0.0, 0.0,   l,   h,
             1.0, 1.0,-1.0, 0xff00008f, 1.0, 0.0, 2*l,   h,
             1.0,-1.0,-1.0, 0xff00008f, 1.0, 1.0, 2*l, 1.0,
            -1.0,-1.0,-1.0, 0xff00008f, 0.0, 1.0, 0.0, 1.0,

            --back
             1.0, 1.0, 1.0, 0xff00008f, 0.0, 0.0, 2*l,   h,
            -1.0, 1.0, 1.0, 0xff00008f, 1.0, 0.0, 1.0,   h,
            -1.0,-1.0, 1.0, 0xff00008f, 1.0, 1.0, 1.0, 1.0,
             1.0,-1.0, 1.0, 0xff00008f, 0.0, 1.0, 0.0, 1.0,
        }

        local ib = {
            --top
            0, 1, 2,
            2, 3, 1,
            --bottom
            4, 5, 6,
            6, 7, 5,
            --left
            8, 9, 10,
            10, 11, 9,
            --right
            12, 13, 14,
            14, 15, 13,
            --front
            16, 17, 18,
            18, 19, 17,
            --back
            20, 21, 22,
            22, 23, 21,
        }

        local mesh = ientity.create_mesh({"p3|c40niu|t20|t21", vb}, ib)
        return create_lm_entity("box", testmaterial, mesh)
    end

    create_plane()
    local b = create_box()
    print (world[b].name)
end

function lm_baker:data_changed()

end